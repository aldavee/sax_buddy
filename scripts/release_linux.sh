#!/usr/bin/env bash
# Zero-GitHub Linux release builder & publisher for Sax Buddy.
# Builds split release APKs on any Linux machine (PC, WSL2, VPS, home server)
# and publishes them directly to Google Drive with zero GitHub dependency.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

INPUT_VERSION=""
RELEASE_NOTES=""
SKIP_TESTS="false"
PUBLIC_RELEASES="${GDRIVE_PUBLIC_RELEASES:-true}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      INPUT_VERSION="${2:-}"
      shift 2
      ;;
    --notes)
      RELEASE_NOTES="${2:-}"
      shift 2
      ;;
    --public)
      PUBLIC_RELEASES="${2:-true}"
      shift 2
      ;;
    --skip-tests)
      SKIP_TESTS="true"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/release_linux.sh [options]

Options:
  --version X.Y.Z+N   Optional explicit version override (auto-increments above Drive max build otherwise)
  --notes "..."       Optional release notes stored in Google Drive release.json / latest_release.json
  --public true|false Share uploaded APKs & manifest publicly (default: true)
  --skip-tests        Skip flutter analyze & flutter test
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Load local .env automatically if present (without overwriting already-exported env vars)
if [[ -f ".env" ]]; then
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line%$'\r'}"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      if [[ -z "${!key:-}" ]]; then
        export "$key=$val"
      fi
    fi
  done < .env
fi

for cmd in flutter python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required on Linux PATH." >&2
    exit 1
  fi
done

tmp_env="$(mktemp)"
cleanup() {
  rm -f "$tmp_env"
}
trap cleanup EXIT

echo "=== 1. Preparing Google Drive release target ==="
python3 scripts/gdrive_release.py prepare \
  --public "$PUBLIC_RELEASES" \
  --write-env "$tmp_env"
# shellcheck source=/dev/null
source "$tmp_env"

echo "=== 2. Resolving monotonic Android version from Drive & pubspec.yaml ==="
pub_version="$(grep '^version:' pubspec.yaml | head -n 1 | awk '{print $2}' | tr -d '\r ')"
pub_name="${pub_version%%+*}"
pub_build=0
if [[ "$pub_version" == *"+"* ]]; then
  cand="${pub_version##*+}"
  [[ "$cand" =~ ^[0-9]+$ ]] && pub_build="$cand"
fi

drive_max_build="${GDRIVE_PREPARED_MAX_BUILD:-0}"
[[ "$drive_max_build" =~ ^[0-9]+$ ]] || drive_max_build=0

if [[ -n "$INPUT_VERSION" ]]; then
  target_name="${INPUT_VERSION%%+*}"
  target_build="${INPUT_VERSION##*+}"
  [[ "$target_build" =~ ^[0-9]+$ ]] || target_build=0
else
  target_name="$pub_name"
  target_build="$pub_build"
fi

if (( target_build <= drive_max_build )); then
  target_build=$(( drive_max_build + 1 ))
fi

final_version="${target_name}+${target_build}"
tag_name="v${final_version}"
echo "Resolved Release Version: $final_version (Drive max build: $drive_max_build)"

FINAL_VER="$final_version" perl -0pi -e 's/^version:\s*.*$/version: $ENV{FINAL_VER}/m' pubspec.yaml

echo "=== 3. Installing dependencies ==="
flutter pub get

if [[ "$SKIP_TESTS" != "true" ]]; then
  echo "=== 4. Running static analysis & tests ==="
  flutter analyze --no-fatal-infos
  flutter test
fi

echo "=== 5. Building signed split release APKs (Google Drive only) ==="
flutter build apk --release --split-per-abi \
  --android-skip-build-dependency-validation \
  --build-name="$target_name" \
  --build-number="$target_build" \
  --dart-define=APP_VERSION="$final_version" \
  --dart-define=GDRIVE_ONLY=true \
  --dart-define=GDRIVE_RELEASE_FOLDER_ID="$GDRIVE_PREPARED_FOLDER_ID" \
  --dart-define=GDRIVE_MANIFEST_FILE_ID="$GDRIVE_PREPARED_MANIFEST_ID" \
  --dart-define=GDRIVE_API_KEY="${GDRIVE_API_KEY:-}" \
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID="${GOOGLE_DESKTOP_CLIENT_ID:-}" \
  --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET="${GOOGLE_DESKTOP_CLIENT_SECRET:-}"

apk_dir="build/app/outputs/flutter-apk"
required_apks=(
  "$apk_dir/app-arm64-v8a-release.apk"
  "$apk_dir/app-armeabi-v7a-release.apk"
  "$apk_dir/app-x86_64-release.apk"
)

android_sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
build_tools_dir=""
if [[ -n "$android_sdk" && -d "$android_sdk/build-tools" ]]; then
  latest_bt="$(ls -1 "$android_sdk/build-tools" | sort -V | tail -n 1 || true)"
  [[ -n "$latest_bt" ]] && build_tools_dir="$android_sdk/build-tools/$latest_bt"
fi

echo "=== 6. Validating generated APKs ==="
for apk in "${required_apks[@]}"; do
  if [[ ! -f "$apk" ]]; then
    echo "Error: Missing expected APK: $apk" >&2
    exit 1
  fi
  size=$(stat -c%s "$apk")
  if (( size < 10000000 )); then
    echo "Error: $apk is smaller than expected ($size bytes)" >&2
    exit 1
  fi
  if [[ -n "$build_tools_dir" ]]; then
    [[ -x "$build_tools_dir/zipalign" ]] && "$build_tools_dir/zipalign" -c 4 "$apk"
    [[ -x "$build_tools_dir/apksigner" ]] && "$build_tools_dir/apksigner" verify --verbose "$apk" >/dev/null
  fi
  echo "  [OK] $apk ($size bytes)"
done

echo "=== 7. Reclaiming temporary Gradle intermediates & staging APKs ==="
rm -rf build/app/intermediates build/app/tmp build/app/kotlin

primary_apk="$apk_dir/sax-buddy-${final_version}.apk"
arm64_apk="$apk_dir/sax-buddy-${final_version}-arm64-v8a.apk"
armeabi_apk="$apk_dir/sax-buddy-${final_version}-armeabi-v7a.apk"
x86_64_apk="$apk_dir/sax-buddy-${final_version}-x86_64.apk"

mv -f "$apk_dir/app-arm64-v8a-release.apk" "$arm64_apk"
mv -f "$apk_dir/app-armeabi-v7a-release.apk" "$armeabi_apk"
mv -f "$apk_dir/app-x86_64-release.apk" "$x86_64_apk"
cp -f "$arm64_apk" "$primary_apk"

echo "=== 8. Publishing APKs to Google Drive (0% GitHub reliance) ==="
notes="${RELEASE_NOTES:-Sax Buddy Release $final_version (built on Linux and published directly to Google Drive).}"
python3 scripts/gdrive_release.py publish \
  --tag "$tag_name" \
  --version "$final_version" \
  --folder-id "$GDRIVE_PREPARED_FOLDER_ID" \
  --manifest-id "$GDRIVE_PREPARED_MANIFEST_ID" \
  --public "$PUBLIC_RELEASES" \
  --notes "$notes" \
  "$primary_apk" \
  "$arm64_apk" \
  "$armeabi_apk" \
  "$x86_64_apk"

echo "=== Complete! Folder: $GDRIVE_PREPARED_FOLDER_URL ==="
