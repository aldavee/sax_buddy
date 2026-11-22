#!/usr/bin/env python3
"""Google Drive release uploader and manifest manager for Sax Buddy CI/CD.

Uses only the Python 3 standard library so GitHub Actions runners require zero
third-party pip dependencies. Supports:
  1. OAuth 2.0 Refresh Token (personal Gmail Google Drive, 15GB quota)
  2. Service Account JSON (Google Workspace Shared Drives)

Subcommands:
  prepare      Ensure target Google Drive release folder and latest_release.json exist.
  publish      Upload validated split APKs to Google Drive and update latest_release.json.
  setup-oauth  Interactive local OAuth helper to generate GDRIVE_REFRESH_TOKEN.
"""

from __future__ import annotations

import argparse
import base64
import datetime
import hashlib
import http.client
import http.server
import json
import os
import re
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from pathlib import Path
from typing import Any

_GCP_PROJECT_NUM = "702325277685"
_DEFAULT_CLIENT_KEY = "lkunpks4cmareffbfgukcungrjqm1llm"
DEFAULT_OAUTH_CLIENT_ID = (
    f"{_GCP_PROJECT_NUM}-{_DEFAULT_CLIENT_KEY}.apps.googleusercontent.com"
)
DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token"
DRIVE_FILES_URL = "https://www.googleapis.com/drive/v3/files"
DRIVE_UPLOAD_URL = "https://www.googleapis.com/upload/drive/v3/files"
DEFAULT_RELEASE_FOLDER_NAME = "Sax Buddy Releases"
MANIFEST_FILE_NAME = "latest_release.json"
MAX_MANIFEST_HISTORY = 10
CHUNK_SIZE = 2 * 1024 * 1024  # 2 MiB multiple of 256 KiB per Drive resumable spec
_TRANSIENT_ERRORS = (
    urllib.error.URLError,
    ssl.SSLError,
    http.client.HTTPException,
    TimeoutError,
    OSError,
)


def _load_dotenv_defaults() -> None:
    """Populate unset environment variables from the repository's .env file if present."""
    repo_root = Path(__file__).resolve().parent.parent
    for candidate in (repo_root / ".env", Path.cwd() / ".env"):
        if not candidate.is_file():
            continue
        try:
            for raw_line in candidate.read_text(encoding="utf-8").splitlines():
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, val = line.partition("=")
                key = key.strip()
                val = val.strip().strip('"').strip("'")
                if key and key not in os.environ:
                    os.environ[key] = val
        except OSError:
            pass
        break


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _http_json(
    url: str,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    body: bytes | None = None,
    timeout: int = 60,
) -> dict[str, Any]:
    req_headers = {"User-Agent": "SaxBuddy-GDrive-Release/1.0"}
    if headers:
        req_headers.update(headers)
    for attempt in range(4):
        req = urllib.request.Request(url, data=body, headers=req_headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw = resp.read().decode("utf-8")
                return json.loads(raw) if raw.strip() else {}
        except urllib.error.HTTPError as exc:
            err_body = exc.read().decode("utf-8", errors="replace")
            if exc.code >= 500 and attempt < 3:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(
                f"HTTP {exc.code} from {url}: {err_body[:1000]}"
            ) from exc
        except _TRANSIENT_ERRORS as exc:
            if attempt < 3:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(
                f"Network error calling {url}: {exc}"
            ) from exc
    raise RuntimeError(f"Exhausted retries calling {url}")


def _exchange_refresh_token(
    client_id: str,
    client_secret: str,
    refresh_token: str,
) -> str:
    payload: dict[str, str] = {
        "grant_type": "refresh_token",
        "client_id": client_id,
        "refresh_token": refresh_token,
    }
    if client_secret:
        payload["client_secret"] = client_secret
    data = urllib.parse.urlencode(payload).encode("utf-8")
    resp = _http_json(
        DEFAULT_TOKEN_URI,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        body=data,
    )
    token = resp.get("access_token", "")
    if not token:
        raise RuntimeError(f"OAuth token exchange succeeded without access_token: {resp}")
    return str(token)


def _exchange_service_account(sa_raw: str) -> str:
    if os.path.isfile(sa_raw):
        sa = json.loads(Path(sa_raw).read_text(encoding="utf-8"))
    else:
        sa = json.loads(sa_raw)

    client_email = sa.get("client_email", "")
    private_key = sa.get("private_key", "")
    token_uri = sa.get("token_uri", DEFAULT_TOKEN_URI)
    if not client_email or not private_key:
        raise RuntimeError(
            "GDRIVE_SERVICE_ACCOUNT_JSON is missing client_email or private_key."
        )

    now = int(time.time())
    header = _b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode("utf-8"))
    claims = _b64url(
        json.dumps(
            {
                "iss": client_email,
                "scope": "https://www.googleapis.com/auth/drive",
                "aud": token_uri,
                "iat": now,
                "exp": now + 3600,
            }
        ).encode("utf-8")
    )
    signing_input = f"{header}.{claims}".encode("ascii")

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as key_file:
        key_file.write(private_key)
        key_path = key_file.name

    try:
        proc = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_path],
            input=signing_input,
            capture_output=True,
            check=True,
        )
        signature = _b64url(proc.stdout)
    finally:
        try:
            os.remove(key_path)
        except OSError:
            pass

    assertion = f"{header}.{claims}.{signature}"
    body = urllib.parse.urlencode(
        {
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        }
    ).encode("utf-8")
    resp = _http_json(
        token_uri,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        body=body,
    )
    token = resp.get("access_token", "")
    if not token:
        raise RuntimeError(
            f"Service account token exchange returned no access_token: {resp}"
        )
    return str(token)


def authenticate_drive_from_env() -> str:
    _load_dotenv_defaults()
    refresh_token = os.environ.get("GDRIVE_REFRESH_TOKEN", "").strip()
    client_id = (
        os.environ.get("GDRIVE_CLIENT_ID", "").strip() or DEFAULT_OAUTH_CLIENT_ID
    )
    client_secret = os.environ.get("GDRIVE_CLIENT_SECRET", "").strip()
    sa_json = os.environ.get("GDRIVE_SERVICE_ACCOUNT_JSON", "").strip()

    if refresh_token:
        try:
            return _exchange_refresh_token(client_id, client_secret, refresh_token)
        except RuntimeError as exc:
            if sa_json:
                print(
                    f"::warning::OAuth refresh token exchange failed ({exc}); "
                    "falling back to GDRIVE_SERVICE_ACCOUNT_JSON.",
                    file=sys.stderr,
                )
                return _exchange_service_account(sa_json)
            err_text = str(exc)
            if "invalid_grant" in err_text:
                raise SystemExit(
                    "::error::Google Drive OAuth refresh token failed with 'invalid_grant' "
                    "(Token has been expired or revoked, or GDRIVE_CLIENT_ID / GDRIVE_CLIENT_SECRET "
                    "does not match the client used to generate GDRIVE_REFRESH_TOKEN).\n"
                    "  - Note: If your Google Cloud OAuth Consent Screen is in 'Testing' mode, "
                    "Google automatically expires refresh tokens after 7 days. Set Publishing status "
                    "to 'In production' in Google Cloud Console -> APIs & Services -> OAuth consent screen.\n"
                    "  - Fix: Run `python scripts/gdrive_release.py setup-oauth` locally to generate a new "
                    "GDRIVE_REFRESH_TOKEN, then update GDRIVE_REFRESH_TOKEN (and GDRIVE_CLIENT_ID / "
                    "GDRIVE_CLIENT_SECRET) in your GitHub Repository/Environment Secrets."
                ) from exc
            raise
    if sa_json:
        return _exchange_service_account(sa_json)

    raise SystemExit(
        "::error::Missing Google Drive upload credentials. Configure either:\n"
        "  1) OAuth Refresh Token (recommended for personal Gmail Drive): "
        "GDRIVE_REFRESH_TOKEN (+ optional GDRIVE_CLIENT_ID / GDRIVE_CLIENT_SECRET)\n"
        "  2) Shared Drive Service Account: GDRIVE_SERVICE_ACCOUNT_JSON"
    )


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def find_item_in_parent(
    token: str,
    *,
    name: str,
    parent_id: str | None,
    mime_type: str | None = None,
) -> dict[str, Any] | None:
    escaped_name = name.replace("\\", "\\\\").replace("'", "\\'")
    clauses = [f"name = '{escaped_name}'", "trashed = false"]
    if parent_id:
        clauses.append(f"'{parent_id}' in parents")
    if mime_type:
        clauses.append(f"mimeType = '{mime_type}'")
    query = " and ".join(clauses)
    params = urllib.parse.urlencode(
        {
            "q": query,
            "fields": "files(id,name,mimeType,size,modifiedTime)",
            "orderBy": "modifiedTime desc",
            "pageSize": "1",
            "supportsAllDrives": "true",
            "includeItemsFromAllDrives": "true",
        }
    )
    res = _http_json(
        f"{DRIVE_FILES_URL}?{params}",
        headers=_auth_headers(token),
    )
    files = res.get("files") or []
    return files[0] if files else None


def get_file_metadata(token: str, file_id: str) -> dict[str, Any]:
    params = urllib.parse.urlencode(
        {
            "fields": "id,name,mimeType,size,parents,trashed",
            "supportsAllDrives": "true",
        }
    )
    return _http_json(
        f"{DRIVE_FILES_URL}/{urllib.parse.quote(file_id)}?{params}",
        headers=_auth_headers(token),
    )


def create_folder(token: str, name: str, parent_id: str | None = None) -> dict[str, Any]:
    metadata: dict[str, Any] = {
        "name": name,
        "mimeType": "application/vnd.google-apps.folder",
    }
    if parent_id:
        metadata["parents"] = [parent_id]
    params = urllib.parse.urlencode(
        {"fields": "id,name", "supportsAllDrives": "true"}
    )
    return _http_json(
        f"{DRIVE_FILES_URL}?{params}",
        method="POST",
        headers={
            **_auth_headers(token),
            "Content-Type": "application/json; charset=utf-8",
        },
        body=json.dumps(metadata).encode("utf-8"),
    )


def ensure_folder(token: str, name: str, parent_id: str | None) -> dict[str, Any]:
    existing = find_item_in_parent(
        token,
        name=name,
        parent_id=parent_id or "root",
        mime_type="application/vnd.google-apps.folder",
    )
    if existing:
        return existing
    return create_folder(token, name, parent_id=parent_id)


def ensure_public_reader(token: str, file_id: str) -> None:
    url = (
        f"{DRIVE_FILES_URL}/{urllib.parse.quote(file_id)}/permissions"
        "?supportsAllDrives=true"
    )
    try:
        _http_json(
            url,
            method="POST",
            headers={
                **_auth_headers(token),
                "Content-Type": "application/json; charset=utf-8",
            },
            body=json.dumps({"role": "reader", "type": "anyone"}).encode("utf-8"),
        )
    except RuntimeError as exc:
        print(
            f"::warning::Could not set 'anyone' reader permission on Drive item {file_id}: {exc}",
            file=sys.stderr,
        )


def read_drive_text_file(token: str, file_id: str) -> str | None:
    url = (
        f"{DRIVE_FILES_URL}/{urllib.parse.quote(file_id)}"
        "?alt=media&supportsAllDrives=true"
    )
    req = urllib.request.Request(
        url,
        headers={
            **_auth_headers(token),
            "User-Agent": "SaxBuddy-GDrive-Release/1.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None
        raise RuntimeError(
            f"Failed reading Drive file {file_id} (HTTP {exc.code})"
        ) from exc


def upsert_text_file(
    token: str,
    *,
    name: str,
    parent_id: str,
    content: str,
    existing_file_id: str | None = None,
    make_public: bool = True,
) -> dict[str, Any]:
    file_id = existing_file_id
    if not file_id:
        found = find_item_in_parent(token, name=name, parent_id=parent_id)
        if found:
            file_id = found["id"]

    payload = content.encode("utf-8")
    if file_id:
        params = urllib.parse.urlencode(
            {
                "uploadType": "media",
                "fields": "id,name,size,modifiedTime",
                "supportsAllDrives": "true",
            }
        )
        updated = _http_json(
            f"{DRIVE_UPLOAD_URL}/{urllib.parse.quote(file_id)}?{params}",
            method="PATCH",
            headers={
                **_auth_headers(token),
                "Content-Type": "application/json; charset=utf-8",
            },
            body=payload,
        )
        if make_public:
            ensure_public_reader(token, updated["id"])
        return updated

    # Multipart create
    boundary = f"notesforme_{int(time.time() * 1000)}"
    meta = json.dumps(
        {
            "name": name,
            "mimeType": "application/json",
            "parents": [parent_id],
        }
    ).encode("utf-8")
    multipart_body = (
        f"--{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".encode(
            "utf-8"
        )
        + meta
        + f"\r\n--{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".encode(
            "utf-8"
        )
        + payload
        + f"\r\n--{boundary}--\r\n".encode("utf-8")
    )
    params = urllib.parse.urlencode(
        {
            "uploadType": "multipart",
            "fields": "id,name,size,modifiedTime",
            "supportsAllDrives": "true",
        }
    )
    created = _http_json(
        f"{DRIVE_UPLOAD_URL}?{params}",
        method="POST",
        headers={
            **_auth_headers(token),
            "Content-Type": f"multipart/related; boundary={boundary}",
        },
        body=multipart_body,
    )
    if make_public:
        ensure_public_reader(token, created["id"])
    return created


def _parse_uploaded_range_end(range_header: str | None) -> int | None:
    if not range_header:
        return None
    m = re.search(r"bytes=\d+-(\d+)", range_header)
    if not m:
        return None
    return int(m.group(1)) + 1


def _query_resumable_offset(
    upload_session_uri: str,
    total_size: int,
) -> tuple[int, dict[str, Any] | None]:
    """Queries Drive for committed byte offset after a transient socket drop."""
    probe_req = urllib.request.Request(
        upload_session_uri,
        data=b"",
        method="PUT",
        headers={
            "Content-Length": "0",
            "Content-Range": f"bytes */{total_size}",
        },
    )
    try:
        with urllib.request.urlopen(probe_req, timeout=60) as probe_resp:
            raw = probe_resp.read().decode("utf-8", errors="replace")
            meta = json.loads(raw) if raw.strip() else None
            return total_size, meta
    except urllib.error.HTTPError as exc:
        if exc.code == 308:
            next_offset = _parse_uploaded_range_end(exc.headers.get("Range"))
            return (next_offset if next_offset is not None else 0), None
        if exc.code in (404, 410):
            return -1, None
        return 0, None
    except _TRANSIENT_ERRORS:
        return 0, None


def _start_resumable_session(
    token: str,
    *,
    drive_name: str,
    parent_id: str,
    mime_type: str,
    total_size: int,
) -> str:
    existing = find_item_in_parent(token, name=drive_name, parent_id=parent_id)
    if existing:
        init_url = (
            f"{DRIVE_UPLOAD_URL}/{urllib.parse.quote(existing['id'])}"
            "?uploadType=resumable&fields=id,name,size,modifiedTime&supportsAllDrives=true"
        )
        init_method = "PATCH"
        meta: dict[str, Any] = {"name": drive_name, "mimeType": mime_type}
    else:
        init_url = (
            f"{DRIVE_UPLOAD_URL}"
            "?uploadType=resumable&fields=id,name,size,modifiedTime&supportsAllDrives=true"
        )
        init_method = "POST"
        meta = {
            "name": drive_name,
            "mimeType": mime_type,
            "parents": [parent_id],
        }

    payload = json.dumps(meta).encode("utf-8")
    for attempt in range(4):
        init_req = urllib.request.Request(
            init_url,
            data=payload,
            method=init_method,
            headers={
                **_auth_headers(token),
                "Content-Type": "application/json; charset=UTF-8",
                "X-Upload-Content-Type": mime_type,
                "X-Upload-Content-Length": str(total_size),
            },
        )
        try:
            with urllib.request.urlopen(init_req, timeout=60) as resp:
                session_uri = resp.headers.get("Location")
            if not session_uri:
                raise RuntimeError(
                    f"Drive resumable init returned no Location header for {drive_name}"
                )
            return session_uri
        except urllib.error.HTTPError as exc:
            err_txt = exc.read().decode("utf-8", errors="replace")
            if exc.code >= 500 and attempt < 3:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(
                f"Drive resumable init failed for {drive_name} (HTTP {exc.code}): {err_txt[:500]}"
            ) from exc
        except _TRANSIENT_ERRORS as exc:
            if attempt < 3:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(
                f"Drive resumable init network error for {drive_name}: {exc}"
            ) from exc
    raise RuntimeError(f"Failed to start Drive upload session for {drive_name}")


def upload_binary_resumable(
    token: str,
    *,
    file_path: Path,
    drive_name: str,
    parent_id: str,
    mime_type: str = "application/vnd.android.package-archive",
    make_public: bool = True,
) -> dict[str, Any]:
    total_size = file_path.stat().st_size
    if total_size <= 0:
        raise RuntimeError(f"Cannot upload empty file: {file_path}")

    upload_session_uri = _start_resumable_session(
        token,
        drive_name=drive_name,
        parent_id=parent_id,
        mime_type=mime_type,
        total_size=total_size,
    )

    result_meta: dict[str, Any] | None = None
    with file_path.open("rb") as fh:
        offset = 0
        consecutive_failures = 0
        while offset < total_size:
            fh.seek(offset)
            chunk = fh.read(CHUNK_SIZE)
            if not chunk:
                break
            end = offset + len(chunk) - 1
            headers = {
                "Content-Length": str(len(chunk)),
                "Content-Range": f"bytes {offset}-{end}/{total_size}",
                "Content-Type": mime_type,
            }
            put_req = urllib.request.Request(
                upload_session_uri,
                data=chunk,
                method="PUT",
                headers=headers,
            )
            try:
                with urllib.request.urlopen(put_req, timeout=300) as put_resp:
                    raw = put_resp.read().decode("utf-8")
                    if raw.strip():
                        result_meta = json.loads(raw)
                offset += len(chunk)
                consecutive_failures = 0
                continue
            except urllib.error.HTTPError as exc:
                if exc.code == 308:
                    # Expected intermediate chunk response in Drive resumable upload
                    committed = _parse_uploaded_range_end(exc.headers.get("Range"))
                    offset = committed if committed is not None else (end + 1)
                    consecutive_failures = 0
                    continue
                if exc.code >= 500 or exc.code in (404, 410):
                    consecutive_failures += 1
                    if consecutive_failures >= 5:
                        err_txt = exc.read().decode("utf-8", errors="replace")
                        raise RuntimeError(
                            f"Chunk upload failed for {drive_name} after retries (HTTP {exc.code}): {err_txt[:500]}"
                        ) from exc
                    time.sleep(min(16, 2 ** (consecutive_failures - 1)))
                    if exc.code in (404, 410):
                        upload_session_uri = _start_resumable_session(
                            token,
                            drive_name=drive_name,
                            parent_id=parent_id,
                            mime_type=mime_type,
                            total_size=total_size,
                        )
                        offset = 0
                        continue
                    probed_offset, probed_meta = _query_resumable_offset(
                        upload_session_uri, total_size
                    )
                    if probed_offset < 0:
                        upload_session_uri = _start_resumable_session(
                            token,
                            drive_name=drive_name,
                            parent_id=parent_id,
                            mime_type=mime_type,
                            total_size=total_size,
                        )
                        offset = 0
                    else:
                        offset = probed_offset
                        if probed_meta is not None:
                            result_meta = probed_meta
                    continue
                err_txt = exc.read().decode("utf-8", errors="replace")
                raise RuntimeError(
                    f"Chunk upload failed for {drive_name} (HTTP {exc.code}): {err_txt[:500]}"
                ) from exc
            except _TRANSIENT_ERRORS as exc:
                consecutive_failures += 1
                if consecutive_failures >= 5:
                    raise RuntimeError(
                        f"Chunk upload network/SSL error for {drive_name} after retries: {exc}"
                    ) from exc
                time.sleep(min(16, 2 ** (consecutive_failures - 1)))
                probed_offset, probed_meta = _query_resumable_offset(
                    upload_session_uri, total_size
                )
                if probed_offset < 0:
                    upload_session_uri = _start_resumable_session(
                        token,
                        drive_name=drive_name,
                        parent_id=parent_id,
                        mime_type=mime_type,
                        total_size=total_size,
                    )
                    offset = 0
                else:
                    offset = probed_offset
                    if probed_meta is not None:
                        result_meta = probed_meta
                continue

    if not result_meta or "id" not in result_meta:
        found = find_item_in_parent(token, name=drive_name, parent_id=parent_id)
        if not found:
            raise RuntimeError(f"Upload finished for {drive_name} without file metadata")
        result_meta = found

    if make_public:
        ensure_public_reader(token, result_meta["id"])
    return result_meta


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        while True:
            buf = fh.read(1024 * 1024)
            if not buf:
                break
            digest.update(buf)
    return digest.hexdigest()


def infer_apk_abi(filename: str) -> str:
    lower = filename.lower()
    if "arm64-v8a" in lower:
        return "arm64-v8a"
    if "armeabi-v7a" in lower:
        return "armeabi-v7a"
    if "x86_64" in lower:
        return "x86_64"
    return "arm64-v8a"


def infer_desktop_target(filename: str) -> tuple[str, str, str]:
    """Returns (platform, arch_label, mime_type) for desktop release artifacts."""
    lower = filename.lower()
    if (
        "windows" in lower
        or lower.endswith(".msi")
        or lower.endswith(".exe")
        or lower.endswith(".msix")
    ):
        arch = "windows-arm64" if "arm64" in lower else "windows-x64"
        if lower.endswith(".msi"):
            mime = "application/x-msi"
        elif lower.endswith(".exe"):
            mime = "application/vnd.microsoft.portable-executable"
        else:
            mime = "application/zip"
        return ("windows", arch, mime)
    if "linux" in lower or lower.endswith(".appimage") or lower.endswith(".tar.gz"):
        arch = "linux-arm64" if "arm64" in lower else "linux-x64"
        return ("linux", arch, "application/gzip" if lower.endswith(".gz") else "application/zip")
    if "macos" in lower or lower.endswith(".dmg"):
        return ("macos", "macos-universal", "application/x-apple-diskimage" if lower.endswith(".dmg") else "application/zip")
    return ("desktop", "windows-x64", "application/zip")


def write_github_outputs(values: dict[str, str]) -> None:
    out_file = os.environ.get("GITHUB_OUTPUT", "").strip()
    if not out_file:
        return
    with open(out_file, "a", encoding="utf-8") as fh:
        for k, v in values.items():
            if "\n" in v:
                delimiter = f"EOF_{k.upper()}_{int(time.time() * 1000)}"
                fh.write(f"{k}<<{delimiter}\n{v}\n{delimiter}\n")
            else:
                fh.write(f"{k}={v}\n")


def extract_max_build_from_manifest(raw_json: str | None) -> int:
    if not raw_json:
        return 0
    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError:
        return 0
    if not isinstance(data, dict):
        return 0

    max_build = 0
    entries: list[dict[str, Any]] = []
    if isinstance(data.get("latest"), dict):
        entries.append(data["latest"])
    if isinstance(data.get("releases"), list):
        entries.extend(item for item in data["releases"] if isinstance(item, dict))

    for entry in entries:
        for key in ("version", "tag_name"):
            val = str(entry.get(key) or "")
            match = re.search(r"\+(\d+)", val)
            if match:
                max_build = max(max_build, int(match.group(1)))
    return max_build


def cmd_prepare(args: argparse.Namespace) -> None:
    token = authenticate_drive_from_env()
    make_public = args.public.lower() != "false"

    explicit_folder_id = args.folder_id.strip() or os.environ.get(
        "GDRIVE_RELEASE_FOLDER_ID", ""
    ).strip()
    if explicit_folder_id:
        folder = get_file_metadata(token, explicit_folder_id)
        if folder.get("trashed") is True:
            raise RuntimeError(
                f"Configured GDRIVE_RELEASE_FOLDER_ID ({explicit_folder_id}) is trashed."
            )
    else:
        folder = ensure_folder(token, args.folder_name, parent_id=None)

    folder_id = folder["id"]
    if make_public:
        ensure_public_reader(token, folder_id)

    existing_manifest_raw: str | None = None
    explicit_manifest_id = args.manifest_id.strip() or os.environ.get(
        "GDRIVE_MANIFEST_FILE_ID", ""
    ).strip()
    if explicit_manifest_id:
        manifest_meta = get_file_metadata(token, explicit_manifest_id)
        manifest_id = manifest_meta["id"]
        existing_manifest_raw = read_drive_text_file(token, manifest_id)
    else:
        existing_manifest = find_item_in_parent(
            token, name=MANIFEST_FILE_NAME, parent_id=folder_id
        )
        if existing_manifest:
            manifest_id = existing_manifest["id"]
            if make_public:
                ensure_public_reader(token, manifest_id)
            existing_manifest_raw = read_drive_text_file(token, manifest_id)
        else:
            initial_manifest = json.dumps(
                {
                    "source": "gdrive",
                    "folder_id": folder_id,
                    "releases": [],
                },
                indent=2,
            )
            created_manifest = upsert_text_file(
                token,
                name=MANIFEST_FILE_NAME,
                parent_id=folder_id,
                content=initial_manifest,
                make_public=make_public,
            )
            manifest_id = created_manifest["id"]

    max_build = extract_max_build_from_manifest(existing_manifest_raw)
    folder_url = f"https://drive.google.com/drive/folders/{folder_id}"
    manifest_url = (
        f"https://drive.usercontent.google.com/download?id={manifest_id}&export=download&confirm=t"
    )

    outputs = {
        "folder_id": folder_id,
        "manifest_file_id": manifest_id,
        "folder_url": folder_url,
        "manifest_url": manifest_url,
        "max_build": str(max_build),
    }
    write_github_outputs(outputs)
    if args.write_env:
        env_path = Path(args.write_env)
        env_path.write_text(
            "\n".join(
                [
                    f"GDRIVE_PREPARED_FOLDER_ID={folder_id}",
                    f"GDRIVE_PREPARED_MANIFEST_ID={manifest_id}",
                    f"GDRIVE_PREPARED_MAX_BUILD={max_build}",
                    f"GDRIVE_PREPARED_FOLDER_URL={folder_url}",
                    f"GDRIVE_PREPARED_MANIFEST_URL={manifest_url}",
                    "",
                ]
            ),
            encoding="utf-8",
        )
    print(json.dumps(outputs, indent=2))


def build_release_manifest(
    *,
    existing_manifest_raw: str | None,
    folder_id: str,
    manifest_file_id: str,
    version_folder_id: str,
    tag_name: str,
    version: str,
    release_name: str,
    notes: str,
    published_at: str,
    uploaded_apks: list[dict[str, Any]],
    uploaded_desktop_builds: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    desktop_list = uploaded_desktop_builds or []
    new_release: dict[str, Any] = {
        "tag_name": tag_name,
        "version": version,
        "name": release_name,
        "body": notes,
        "published_at": published_at,
        "folder_id": version_folder_id,
        "folder_url": f"https://drive.google.com/drive/folders/{version_folder_id}",
        "apks": uploaded_apks,
        "desktop_builds": desktop_list,
    }

    history: list[dict[str, Any]] = []
    if existing_manifest_raw:
        try:
            parsed = json.loads(existing_manifest_raw)
            if isinstance(parsed, dict) and isinstance(parsed.get("releases"), list):
                for item in parsed["releases"]:
                    if (
                        isinstance(item, dict)
                        and item.get("tag_name")
                        and item.get("tag_name") != tag_name
                        and (item.get("apks") or item.get("desktop_builds"))
                    ):
                        history.append(item)
        except json.JSONDecodeError:
            pass

    releases = [new_release] + history[: MAX_MANIFEST_HISTORY - 1]
    return {
        "source": "gdrive",
        "folder_id": folder_id,
        "manifest_file_id": manifest_file_id,
        "updated_at": published_at,
        "latest": new_release,
        "releases": releases,
    }


def _upload_apk_list(
    token: str,
    raw_paths: list[str],
    *,
    version_folder_id: str,
    tag_label: str,
    make_public: bool,
) -> list[dict[str, Any]]:
    uploaded_apks: list[dict[str, Any]] = []
    for raw_path in raw_paths:
        apk_path = Path(raw_path)
        if not apk_path.is_file():
            raise SystemExit(f"::error::APK file not found for Drive upload: {apk_path}")
        size_bytes = apk_path.stat().st_size
        checksum = sha256_file(apk_path)
        print(
            f"Uploading {apk_path.name} ({size_bytes} bytes) to Google Drive folder {tag_label}..."
        )
        uploaded = upload_binary_resumable(
            token,
            file_path=apk_path,
            drive_name=apk_path.name,
            parent_id=version_folder_id,
            make_public=make_public,
        )
        file_id = uploaded["id"]
        uploaded_apks.append(
            {
                "name": apk_path.name,
                "abi": infer_apk_abi(apk_path.name),
                "file_id": file_id,
                "size": size_bytes,
                "sha256": checksum,
                "download_url": (
                    f"https://drive.usercontent.google.com/download?id={file_id}&export=download&confirm=t"
                ),
                "fallback_download_url": (
                    f"https://drive.google.com/uc?export=download&confirm=t&id={file_id}"
                ),
                "api_download_url": (
                    f"https://www.googleapis.com/drive/v3/files/{file_id}?alt=media"
                ),
                "web_view_url": f"https://drive.google.com/file/d/{file_id}/view",
            }
        )
    return uploaded_apks


def _upload_desktop_list(
    token: str,
    raw_paths: list[str],
    *,
    version_folder_id: str,
    tag_label: str,
    make_public: bool,
) -> list[dict[str, Any]]:
    uploaded_desktop_builds: list[dict[str, Any]] = []
    for raw_path in raw_paths:
        desk_path = Path(raw_path)
        if not desk_path.is_file():
            raise SystemExit(
                f"::error::Desktop build file not found for Drive upload: {desk_path}"
            )
        size_bytes = desk_path.stat().st_size
        checksum = sha256_file(desk_path)
        platform_name, arch_label, mime_type = infer_desktop_target(desk_path.name)
        print(
            f"Uploading {desk_path.name} ({size_bytes} bytes, {platform_name}/{arch_label}) to Google Drive folder {tag_label}..."
        )
        uploaded = upload_binary_resumable(
            token,
            file_path=desk_path,
            drive_name=desk_path.name,
            parent_id=version_folder_id,
            mime_type=mime_type,
            make_public=make_public,
        )
        file_id = uploaded["id"]
        uploaded_desktop_builds.append(
            {
                "name": desk_path.name,
                "platform": platform_name,
                "abi": arch_label,
                "file_id": file_id,
                "size": size_bytes,
                "sha256": checksum,
                "download_url": (
                    f"https://drive.usercontent.google.com/download?id={file_id}&export=download&confirm=t"
                ),
                "fallback_download_url": (
                    f"https://drive.google.com/uc?export=download&confirm=t&id={file_id}"
                ),
                "api_download_url": (
                    f"https://www.googleapis.com/drive/v3/files/{file_id}?alt=media"
                ),
                "web_view_url": f"https://drive.google.com/file/d/{file_id}/view",
            }
        )
    return uploaded_desktop_builds


def _write_manifest_and_outputs(
    token: str,
    *,
    folder_id: str,
    manifest_id: str,
    version_folder_id: str,
    tag: str,
    version: str,
    notes: str,
    make_public: bool,
    uploaded_apks: list[dict[str, Any]],
    uploaded_desktop_builds: list[dict[str, Any]],
) -> None:
    existing_manifest_raw = (
        read_drive_text_file(token, manifest_id) if manifest_id else None
    )
    published_at = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    resolved_notes = (
        notes.strip()
        or f"Sax Buddy {version} signed release builds hosted on Google Drive."
    )

    if not manifest_id:
        created_placeholder = upsert_text_file(
            token,
            name=MANIFEST_FILE_NAME,
            parent_id=folder_id,
            content="{}",
            make_public=make_public,
        )
        manifest_id = created_placeholder["id"]

    manifest_obj = build_release_manifest(
        existing_manifest_raw=existing_manifest_raw,
        folder_id=folder_id,
        manifest_file_id=manifest_id,
        version_folder_id=version_folder_id,
        tag_name=tag,
        version=version,
        release_name=f"Release {tag}",
        notes=resolved_notes,
        published_at=published_at,
        uploaded_apks=uploaded_apks,
        uploaded_desktop_builds=uploaded_desktop_builds,
    )
    manifest_json = json.dumps(manifest_obj, indent=2)

    upsert_text_file(
        token,
        name=MANIFEST_FILE_NAME,
        parent_id=folder_id,
        content=manifest_json,
        existing_file_id=manifest_id,
        make_public=make_public,
    )
    upsert_text_file(
        token,
        name="release.json",
        parent_id=version_folder_id,
        content=json.dumps(manifest_obj["latest"], indent=2),
        make_public=make_public,
    )

    folder_url = f"https://drive.google.com/drive/folders/{folder_id}"
    version_folder_url = f"https://drive.google.com/drive/folders/{version_folder_id}"
    manifest_url = (
        f"https://drive.usercontent.google.com/download?id={manifest_id}&export=download&confirm=t"
    )

    lines = [
        f"### Google Drive Release Downloads (`{tag}`)",
        "",
        f"- **Release Folder**: [Open in Google Drive]({version_folder_url})",
        f"- **Manifest (`latest_release.json`)**: [`{manifest_id}`]({manifest_url})",
        "",
        "| Artifact | ABI | Size | Download Link |",
        "| :--- | :--- | :--- | :--- |",
    ]
    for apk in uploaded_apks:
        mb = apk["size"] / (1024 * 1024)
        lines.append(
            f"| `{apk['name']}` | `{apk['abi']}` | {mb:.1f} MB | [Google Drive Download]({apk['web_view_url']}) |"
        )
    for desk in uploaded_desktop_builds:
        mb = desk["size"] / (1024 * 1024)
        lines.append(
            f"| `{desk['name']}` | `{desk['abi']}` | {mb:.1f} MB | [Google Drive Download]({desk['web_view_url']}) |"
        )
    markdown_table = "\n".join(lines)

    outputs = {
        "folder_id": folder_id,
        "version_folder_id": version_folder_id,
        "manifest_file_id": manifest_id,
        "folder_url": folder_url,
        "version_folder_url": version_folder_url,
        "manifest_url": manifest_url,
        "apk_links_markdown": markdown_table,
    }
    write_github_outputs(outputs)
    print(
        f"Published {len(uploaded_apks)} APK(s) and {len(uploaded_desktop_builds)} desktop build(s) to Google Drive folder {version_folder_url}"
    )


def cmd_ensure_folder(args: argparse.Namespace) -> None:
    token = authenticate_drive_from_env()
    make_public = args.public.lower() != "false"
    folder_id = args.folder_id.strip() or os.environ.get(
        "GDRIVE_RELEASE_FOLDER_ID", ""
    ).strip()
    if not folder_id:
        raise SystemExit("::error::--folder-id is required for ensure-folder")
    version_folder = ensure_folder(token, args.tag, parent_id=folder_id)
    version_folder_id = version_folder["id"]
    if make_public:
        ensure_public_reader(token, version_folder_id)
    write_github_outputs({"version_folder_id": version_folder_id})
    print(json.dumps({"version_folder_id": version_folder_id}, indent=2))


def cmd_upload(args: argparse.Namespace) -> None:
    token = authenticate_drive_from_env()
    make_public = args.public.lower() != "false"
    version_folder_id = args.version_folder_id.strip()
    if not version_folder_id:
        raise SystemExit("::error::--version-folder-id is required for upload")

    uploaded_apks = _upload_apk_list(
        token,
        args.apks,
        version_folder_id=version_folder_id,
        tag_label=args.tag or version_folder_id,
        make_public=make_public,
    )
    uploaded_desktop = _upload_desktop_list(
        token,
        getattr(args, "desktop", []) or [],
        version_folder_id=version_folder_id,
        tag_label=args.tag or version_folder_id,
        make_public=make_public,
    )
    write_github_outputs(
        {
            "apks_json": json.dumps(uploaded_apks),
            "desktop_json": json.dumps(uploaded_desktop),
        }
    )


def cmd_finalize(args: argparse.Namespace) -> None:
    token = authenticate_drive_from_env()
    make_public = args.public.lower() != "false"
    folder_id = args.folder_id.strip()
    manifest_id = args.manifest_id.strip()
    version_folder_id = args.version_folder_id.strip()
    apks_raw = os.environ.get("APKS_JSON", "").strip() or args.apks_json.strip() or "[]"
    desktop_raw = (
        os.environ.get("DESKTOP_JSON", "").strip() or args.desktop_json.strip() or "[]"
    )
    uploaded_apks = json.loads(apks_raw)
    uploaded_desktop_builds = json.loads(desktop_raw)
    _write_manifest_and_outputs(
        token,
        folder_id=folder_id,
        manifest_id=manifest_id,
        version_folder_id=version_folder_id,
        tag=args.tag,
        version=args.version,
        notes=args.notes,
        make_public=make_public,
        uploaded_apks=uploaded_apks,
        uploaded_desktop_builds=uploaded_desktop_builds,
    )


def cmd_publish(args: argparse.Namespace) -> None:
    token = authenticate_drive_from_env()
    make_public = args.public.lower() != "false"

    folder_id = args.folder_id.strip() or os.environ.get(
        "GDRIVE_RELEASE_FOLDER_ID", ""
    ).strip()
    if not folder_id:
        folder = ensure_folder(token, args.folder_name, parent_id=None)
        folder_id = folder["id"]
    if make_public:
        ensure_public_reader(token, folder_id)

    manifest_id = args.manifest_id.strip() or os.environ.get(
        "GDRIVE_MANIFEST_FILE_ID", ""
    ).strip()
    if not manifest_id:
        existing_manifest = find_item_in_parent(
            token, name=MANIFEST_FILE_NAME, parent_id=folder_id
        )
        manifest_id = existing_manifest["id"] if existing_manifest else ""

    version_folder = ensure_folder(token, args.tag, parent_id=folder_id)
    version_folder_id = version_folder["id"]
    if make_public:
        ensure_public_reader(token, version_folder_id)

    uploaded_apks = _upload_apk_list(
        token,
        args.apks,
        version_folder_id=version_folder_id,
        tag_label=args.tag,
        make_public=make_public,
    )
    uploaded_desktop_builds = _upload_desktop_list(
        token,
        getattr(args, "desktop", []) or [],
        version_folder_id=version_folder_id,
        tag_label=args.tag,
        make_public=make_public,
    )
    _write_manifest_and_outputs(
        token,
        folder_id=folder_id,
        manifest_id=manifest_id,
        version_folder_id=version_folder_id,
        tag=args.tag,
        version=args.version,
        notes=args.notes,
        make_public=make_public,
        uploaded_apks=uploaded_apks,
        uploaded_desktop_builds=uploaded_desktop_builds,
    )


def _upsert_env_keys(env_path: Path, updates: dict[str, str]) -> bool:
    if not env_path.is_file():
        return False
    content = env_path.read_text(encoding="utf-8")
    for k, v in updates.items():
        pattern = re.compile(rf"(?m)^{re.escape(k)}=.*$")
        if pattern.search(content):
            content = pattern.sub(f"{k}={v}", content)
        else:
            if not content.endswith("\n"):
                content += "\n"
            content += f"{k}={v}\n"
    env_path.write_text(content, encoding="utf-8")
    return True


def cmd_setup_oauth(args: argparse.Namespace) -> None:
    """Interactive OAuth loopback flow for generating a CI GDRIVE_REFRESH_TOKEN."""
    _load_dotenv_defaults()
    client_id = (
        args.client_id.strip()
        or os.environ.get("GDRIVE_CLIENT_ID", "").strip()
        or DEFAULT_OAUTH_CLIENT_ID
    )
    client_secret = (
        args.client_secret.strip()
        or os.environ.get("GDRIVE_CLIENT_SECRET", "").strip()
    )
    captured: dict[str, str] = {}

    class _CallbackHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            parsed = urllib.parse.urlparse(self.path)
            qs = urllib.parse.parse_qs(parsed.query)
            if "code" in qs:
                captured["code"] = qs["code"][0]
            if "error" in qs:
                captured["error"] = qs["error"][0]
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(
                b"<html><body><h2>Google Drive OAuth authorized. You may close this tab and return to the terminal.</h2></body></html>"
            )

        def log_message(self, format: str, *args: Any) -> None:
            return

    server = http.server.HTTPServer(("127.0.0.1", 0), _CallbackHandler)
    redirect_uri = f"http://127.0.0.1:{server.server_port}"
    auth_params = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": "https://www.googleapis.com/auth/drive",
            "access_type": "offline",
            "prompt": "consent",
        }
    )
    auth_url = f"https://accounts.google.com/o/oauth2/v2/auth?{auth_params}"
    print("\nOpen this URL in your browser to authorize Sax Buddy CI Google Drive access:\n")
    print(auth_url)
    print("\nWaiting for OAuth callback on", redirect_uri, "...\n")
    try:
        webbrowser.open(auth_url)
    except Exception:
        pass

    server.handle_request()
    server.server_close()

    if "error" in captured:
        raise SystemExit(f"OAuth authorization failed: {captured['error']}")
    code = captured.get("code", "")
    if not code:
        raise SystemExit("No authorization code received.")

    token_payload: dict[str, str] = {
        "code": code,
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "grant_type": "authorization_code",
    }
    if client_secret:
        token_payload["client_secret"] = client_secret
    token_resp = _http_json(
        DEFAULT_TOKEN_URI,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        body=urllib.parse.urlencode(token_payload).encode("utf-8"),
    )
    refresh_token = token_resp.get("refresh_token", "")
    if not refresh_token:
        raise SystemExit(
            f"Google did not return a refresh_token (ensure prompt=consent): {token_resp}"
        )

    updates = {"GDRIVE_CLIENT_ID": client_id, "GDRIVE_REFRESH_TOKEN": refresh_token}
    if client_secret:
        updates["GDRIVE_CLIENT_SECRET"] = client_secret

    if not getattr(args, "no_write_env", False):
        repo_root = Path(__file__).resolve().parent.parent
        candidates = [
            repo_root / ".env",
            repo_root.parent / "env_configs" / "sax_buddy.env",
        ]
        for env_file in candidates:
            if _upsert_env_keys(env_file, updates):
                print(f"Updated {env_file}")

    print("\n=== Copy these into GitHub Repository Secrets ===")
    print(f"GDRIVE_CLIENT_ID={client_id}")
    if client_secret:
        print(f"GDRIVE_CLIENT_SECRET={client_secret}")
    print(f"GDRIVE_REFRESH_TOKEN={refresh_token}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    p_prepare = subparsers.add_parser("prepare", help="Prepare Drive release folder & manifest ID")
    p_prepare.add_argument("--folder-id", default="")
    p_prepare.add_argument("--folder-name", default=DEFAULT_RELEASE_FOLDER_NAME)
    p_prepare.add_argument("--manifest-id", default="")
    p_prepare.add_argument("--public", default="true")
    p_prepare.add_argument("--write-env", default="", help="Optional path to write key=value env file")
    p_prepare.set_defaults(func=cmd_prepare)

    p_ensure = subparsers.add_parser("ensure-folder", help="Ensure a version subfolder exists under release folder")
    p_ensure.add_argument("--folder-id", required=True)
    p_ensure.add_argument("--tag", required=True)
    p_ensure.add_argument("--public", default="true")
    p_ensure.set_defaults(func=cmd_ensure_folder)

    p_upload = subparsers.add_parser("upload", help="Upload APK or Desktop artifacts to a version folder without updating manifest")
    p_upload.add_argument("--version-folder-id", required=True)
    p_upload.add_argument("--tag", default="")
    p_upload.add_argument("--public", default="true")
    p_upload.add_argument("--desktop", nargs="*", default=[])
    p_upload.add_argument("apks", nargs="*")
    p_upload.set_defaults(func=cmd_upload)

    p_finalize = subparsers.add_parser("finalize", help="Update latest_release.json & release.json from uploaded artifact JSON")
    p_finalize.add_argument("--tag", required=True)
    p_finalize.add_argument("--version", required=True)
    p_finalize.add_argument("--folder-id", required=True)
    p_finalize.add_argument("--manifest-id", required=True)
    p_finalize.add_argument("--version-folder-id", required=True)
    p_finalize.add_argument("--notes", default="")
    p_finalize.add_argument("--public", default="true")
    p_finalize.add_argument("--apks-json", default="")
    p_finalize.add_argument("--desktop-json", default="")
    p_finalize.set_defaults(func=cmd_finalize)

    p_publish = subparsers.add_parser("publish", help="Upload APKs & update manifest on Drive")
    p_publish.add_argument("--tag", required=True)
    p_publish.add_argument("--version", required=True)
    p_publish.add_argument("--folder-id", default="")
    p_publish.add_argument("--folder-name", default=DEFAULT_RELEASE_FOLDER_NAME)
    p_publish.add_argument("--manifest-id", default="")
    p_publish.add_argument("--notes", default="")
    p_publish.add_argument("--public", default="true")
    p_publish.add_argument(
        "--desktop",
        nargs="*",
        default=[],
        help="Optional paths to Desktop build archives/installers (e.g. Windows x64 zip)",
    )
    p_publish.add_argument("apks", nargs="+", help="Paths to APK files to upload")
    p_publish.set_defaults(func=cmd_publish)

    p_oauth = subparsers.add_parser("setup-oauth", help="Generate GDRIVE_REFRESH_TOKEN locally")
    p_oauth.add_argument("--client-id", default="", help="OAuth 2.0 Client ID (defaults to GDRIVE_CLIENT_ID from .env)")
    p_oauth.add_argument("--client-secret", default="", help="OAuth 2.0 Client Secret (defaults to GDRIVE_CLIENT_SECRET from .env)")
    p_oauth.add_argument("--no-write-env", action="store_true", help="Do not automatically update .env with the new refresh token")
    p_oauth.set_defaults(func=cmd_setup_oauth)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

