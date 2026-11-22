# Sax Buddy (Android & Desktop)

Offline-first saxophone practice companion, interactive 23-key fingering chart & altissimo explorer, precision metronome & reference pitch drone, scales & jazz patterns trainer, smart Eb/Bb/Concert horn transposer, practice log & repertoire studio, biometric vault, and Google Drive sync built with Flutter for **Android**, **Windows**, and **Linux**.

## Features

- **Interactive 23-Key Saxophone Fingering Chart & Altissimo Explorer**: Visual key diagram (`Low Bb3` → `High F#6` → `Altissimo G6–D7`) for **Alto (Eb)**, **Tenor (Bb)**, **Soprano (Bb)**, and **Baritone (Eb)** saxophones with primary & alternate fingerings, intonation/voicing tips, and reference concert Hz.
- **Precision Metronome, Reference Pitch Drone & Practice Timer**: Interactive BPM (`30–260 BPM`), tap tempo, time signatures (`4/4`, `3/4`, `2/4`, `6/8`, `5/4`, `7/8`), subdivisions (Quarter, Eighth, Triplet, Sixteenth, Jazz Swing), accent matrix (including 2 & 4 Jazz Backbeat), visual pendulum/LED beat display, and session timer that logs straight into your Practice Log.
- **Scales, Arpeggios & Jazz Vocabulary Trainer**: All 12 keys across Major, Minor, Dorian, Mixolydian, Blues, Pentatonic, Bebop Dominant, Whole Tone, Diminished, and 7th Arpeggios with note-by-note fingerings, target BPM mastery tracking, and 1-tap Metronome launch.
- **Smart Horn Transposer (Concert C ↔ Eb Alto/Bari ↔ Bb Tenor/Soprano)**: Instantly transpose single notes, jazz chord changes (`Cm7 - F7 - BbMaj7`), or melodic lines between Concert Pitch, Eb, and Bb horns.
- **Practice Log, Repertoire & Gear Locker**: Offline-first practice routines, repertoire charts, and reed/mouthpiece setup logs with checklists, folders (`Daily Routine`, `Repertoire`, `Technique`, `Transcribing`, `Gear & Reeds`), `#tags`, color accents, and biometric lock.
- **Biometric App Lock & Locked Entries**: Optional fingerprint / Face Unlock / Windows Hello / device PIN protection (`local_auth`).
- **Google Drive Sync & JSON Backup**: Back up and merge practice logs, repertoire, and scale mastery across devices via Google Drive (`Sax Buddy/sax_buddy_backup.json`) or clipboard JSON export/import.
- **In-App Version Checker & Google Drive Updater**: Checks Google Drive `latest_release.json`, `https://saxbuddy.aldavelabs.com`, or GitHub Releases and installs signed split-ABI APKs on Android.
- **Adaptive Desktop & Mobile UI**: `NavigationRail` sidebar on wide screens, Light/Dark/System themes, and keyboard shortcuts (`Ctrl+N`, `Ctrl+F`, `Space` for Metronome, `F5` for Drive Sync).

## How to Run Locally

### 1. Prerequisites
- **Flutter SDK** (stable channel, Dart `^3.5.0`)
- **Android Studio / Android SDK** (for Android emulator, device debugging, or split-ABI APK builds)
- **Visual Studio 2022** with *Desktop development with C++* (for Windows desktop builds)
- **Python 3** (optional, for `scripts/gdrive_release.py` and `scripts/generate_icons.py`)

### 2. Install Dependencies & Configure Environment
```powershell
cd D:\wsv2\sax_buddy

# Copy the environment template if .env does not exist yet
if (-not (Test-Path .env)) { Copy-Item .env.example .env }

# Fetch Flutter packages
flutter pub get
```

### 3. Run the App (Development)

#### Windows Desktop
`DesktopOAuthClient` automatically loads `GOOGLE_DESKTOP_CLIENT_ID` and `GOOGLE_DESKTOP_CLIENT_SECRET` from your local `.env` file, or you can pass them via `--dart-define`:
```powershell
flutter run -d windows
```

#### Android (Device or Emulator)
```powershell
flutter run -d android
```

#### Linux Desktop
```bash
flutter run -d linux
```

### 4. Run Static Analysis & Tests
```powershell
flutter analyze --no-fatal-infos
flutter test
```

---

## Building Releases & Google Drive Publishing

### Build Android Split-ABI Release APKs Locally
```powershell
flutter build apk --release --split-per-abi `
  --dart-define=APP_VERSION="1.0.0+1" `
  --dart-define=GDRIVE_ONLY=true
```

### Build Windows Desktop Release Locally
```powershell
flutter build windows --release `
  --dart-define=APP_VERSION="1.0.0+1" `
  --dart-define=GDRIVE_ONLY=true
```

### Generate / Refresh `GDRIVE_REFRESH_TOKEN` for CI/CD
```powershell
python scripts/gdrive_release.py setup-oauth
```

### Direct Linux Build & Google Drive Upload (Zero GitHub Actions)
```bash
./scripts/release_linux.sh
```

---

## Android Configuration

- **Application ID**: `com.aldavelabs.sax_buddy`
- **Release Portal**: `https://saxbuddy.aldavelabs.com`

## CI/CD Secrets & Variables (GitHub Actions → `production` environment)

Same Google Drive & Android signing pattern as `notes_for_me` and `pocket_shelf`:

- `GDRIVE_REFRESH_TOKEN`, `GDRIVE_CLIENT_ID`, `GDRIVE_CLIENT_SECRET` (or `GDRIVE_SERVICE_ACCOUNT_JSON`)
- `GDRIVE_RELEASE_FOLDER_ID`, `GDRIVE_MANIFEST_FILE_ID`, `GDRIVE_API_KEY`, `GDRIVE_PUBLIC_RELEASES`
- `GOOGLE_DESKTOP_CLIENT_ID`, `GOOGLE_DESKTOP_CLIENT_SECRET`
- `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
