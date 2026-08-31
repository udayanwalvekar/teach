#!/usr/bin/env python3
"""Resolve the newest verified Teach prompt with safe local fallbacks."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path, PurePosixPath
from typing import Any, Optional

BOOTSTRAP_VERSION = 1
DEFAULT_BASE_URL = (
    "https://raw.githubusercontent.com/udayanwalvekar/teach/"
    "main/plugins/teach/skills/teach"
)
MAX_MANIFEST_BYTES = 256 * 1024
MAX_FILE_BYTES = 512 * 1024
MAX_BUNDLE_BYTES = 2 * 1024 * 1024
SKILL_ROOT = Path(__file__).resolve().parent.parent
BUNDLED_MANIFEST = SKILL_ROOT / "runtime" / "manifest.json"
BUNDLED_RUNTIME = SKILL_ROOT / "runtime" / "teach.md"


class RuntimeResolutionError(Exception):
    pass


def debug(message: str) -> None:
    if os.environ.get("TEACH_UPDATE_DEBUG"):
        print(f"Teach update: {message}", file=sys.stderr)


def updates_disabled() -> bool:
    return os.environ.get("TEACH_DISABLE_UPDATES", "").lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


def timeout_seconds() -> float:
    raw = os.environ.get("TEACH_UPDATE_TIMEOUT_SECONDS", "2")
    try:
        value = float(raw)
    except ValueError as exc:
        raise RuntimeResolutionError(
            "TEACH_UPDATE_TIMEOUT_SECONDS must be a number"
        ) from exc
    if value <= 0 or value > 30:
        raise RuntimeResolutionError(
            "TEACH_UPDATE_TIMEOUT_SECONDS must be between 0 and 30"
        )
    return value


def cache_root() -> Path:
    override = os.environ.get("TEACH_CACHE_DIR")
    if override:
        return Path(override).expanduser()
    if os.name == "nt":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            return Path(local_app_data) / "Teach" / "cache"
    xdg_cache = os.environ.get("XDG_CACHE_HOME")
    if xdg_cache:
        return Path(xdg_cache).expanduser() / "teach"
    return Path.home() / ".cache" / "teach"


def read_limited(response: Any, limit: int) -> bytes:
    data = response.read(limit + 1)
    if len(data) > limit:
        raise RuntimeResolutionError("download exceeded Teach's size limit")
    return data


def fetch(url: str, timeout: float, limit: int) -> bytes:
    request = urllib.request.Request(
        url, headers={"User-Agent": "Teach prompt updater"}
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return read_limited(response, limit)


def safe_relative_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw:
        raise RuntimeResolutionError("manifest contains an invalid path")
    path = PurePosixPath(raw)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        raise RuntimeResolutionError("manifest contains an unsafe path")
    if path.suffix != ".md" or path.parts[0] not in {"runtime", "references"}:
        raise RuntimeResolutionError(
            "manifest may contain only Teach prompt Markdown files"
        )
    return path.as_posix()


def parse_manifest(data: bytes) -> tuple[dict[str, Any], list[tuple[str, str]], str]:
    try:
        manifest = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RuntimeResolutionError("prompt manifest is not valid JSON") from exc
    if (
        not isinstance(manifest, dict)
        or type(manifest.get("schema_version")) is not int
        or manifest.get("schema_version") != 1
    ):
        raise RuntimeResolutionError("prompt manifest schema is not supported")
    minimum = manifest.get("minimum_bootstrap_version")
    if type(minimum) is not int or minimum < 1 or minimum > BOOTSTRAP_VERSION:
        raise RuntimeResolutionError("prompt update requires a newer Teach installer")
    version = manifest.get("prompt_version")
    if not isinstance(version, str) or not version or len(version) > 80:
        raise RuntimeResolutionError("prompt manifest has an invalid version")
    raw_files = manifest.get("files")
    if not isinstance(raw_files, list) or not raw_files or len(raw_files) > 50:
        raise RuntimeResolutionError("prompt manifest has an invalid file list")

    files: list[tuple[str, str]] = []
    seen: set[str] = set()
    for item in raw_files:
        if not isinstance(item, dict):
            raise RuntimeResolutionError(
                "prompt manifest contains an invalid file entry"
            )
        path = safe_relative_path(item.get("path"))
        digest = item.get("sha256")
        if (
            not isinstance(digest, str)
            or len(digest) != 64
            or any(character not in "0123456789abcdef" for character in digest)
        ):
            raise RuntimeResolutionError(
                "prompt manifest contains an invalid SHA-256 hash"
            )
        if path in seen:
            raise RuntimeResolutionError("prompt manifest contains a duplicate path")
        seen.add(path)
        files.append((path, digest))
    if "runtime/teach.md" not in seen:
        raise RuntimeResolutionError(
            "prompt manifest does not contain runtime/teach.md"
        )

    canonical = "\n".join(f"{path}\0{digest}" for path, digest in files).encode("utf-8")
    bundle_digest = hashlib.sha256(canonical).hexdigest()
    return manifest, files, bundle_digest


def verify_bundle(root: Path, files: list[tuple[str, str]]) -> bool:
    for relative_path, expected_digest in files:
        path = root / relative_path
        try:
            if not path.is_file():
                return False
            actual_digest = hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError:
            return False
        if actual_digest != expected_digest:
            return False
    return True


def manifest_url(base_url: str) -> str:
    return f"{base_url.rstrip('/')}/runtime/manifest.json"


def file_url(base_url: str, relative_path: str) -> str:
    encoded = "/".join(
        urllib.parse.quote(part, safe="") for part in relative_path.split("/")
    )
    return f"{base_url.rstrip('/')}/{encoded}"


def install_remote_bundle(
    base_url: str,
    manifest_data: bytes,
    files: list[tuple[str, str]],
    bundle_digest: str,
    timeout: float,
    root: Path,
) -> Path:
    bundles = root / "bundles"
    destination = bundles / bundle_digest
    if verify_bundle(destination, files):
        return destination / "runtime" / "teach.md"

    bundles.mkdir(parents=True, exist_ok=True)
    if destination.is_symlink() or destination.is_file():
        destination.unlink()
    elif destination.is_dir():
        shutil.rmtree(destination)
    staging = Path(tempfile.mkdtemp(prefix=".download-", dir=bundles))
    try:
        total_bytes = 0
        for relative_path, expected_digest in files:
            data = fetch(file_url(base_url, relative_path), timeout, MAX_FILE_BYTES)
            total_bytes += len(data)
            if total_bytes > MAX_BUNDLE_BYTES:
                raise RuntimeResolutionError(
                    "prompt bundle exceeded Teach's size limit"
                )
            if hashlib.sha256(data).hexdigest() != expected_digest:
                raise RuntimeResolutionError(
                    f"prompt hash did not match for {relative_path}"
                )
            target = staging / relative_path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        (staging / "manifest.json").write_bytes(manifest_data)
        try:
            staging.replace(destination)
        except OSError:
            if not verify_bundle(destination, files):
                raise
        return destination / "runtime" / "teach.md"
    finally:
        if staging.exists():
            shutil.rmtree(staging, ignore_errors=True)


def cached_runtime(root: Path) -> Optional[Path]:
    bundles = root / "bundles"
    if not bundles.is_dir():
        return None
    try:
        candidates = sorted(
            (
                path
                for path in bundles.iterdir()
                if path.is_dir() and not path.name.startswith(".")
            ),
            key=lambda path: path.stat().st_mtime,
            reverse=True,
        )
    except OSError:
        return None
    for candidate in candidates:
        manifest_path = candidate / "manifest.json"
        try:
            _, files, _ = parse_manifest(manifest_path.read_bytes())
        except (OSError, RuntimeResolutionError):
            continue
        if verify_bundle(candidate, files):
            return candidate / "runtime" / "teach.md"
    return None


def bundled_runtime() -> Path:
    try:
        _, files, _ = parse_manifest(BUNDLED_MANIFEST.read_bytes())
    except OSError as exc:
        raise RuntimeResolutionError(
            "bundled Teach prompt manifest is missing"
        ) from exc
    if not verify_bundle(SKILL_ROOT, files):
        raise RuntimeResolutionError("bundled Teach prompt did not pass verification")
    return BUNDLED_RUNTIME


def bundled_digest() -> Optional[str]:
    try:
        _, files, digest = parse_manifest(BUNDLED_MANIFEST.read_bytes())
    except (OSError, RuntimeResolutionError):
        return None
    return digest if verify_bundle(SKILL_ROOT, files) else None


def resolve() -> Path:
    if updates_disabled():
        debug("updates disabled; using bundled prompt")
        return bundled_runtime()

    root = cache_root()
    base_url = os.environ.get("TEACH_UPDATE_BASE_URL", DEFAULT_BASE_URL)
    try:
        timeout = timeout_seconds()
        manifest_data = fetch(manifest_url(base_url), timeout, MAX_MANIFEST_BYTES)
        _, files, bundle_digest = parse_manifest(manifest_data)
        if bundle_digest == bundled_digest():
            debug("installed prompt is current")
            return BUNDLED_RUNTIME
        path = install_remote_bundle(
            base_url, manifest_data, files, bundle_digest, timeout, root
        )
        debug(f"using verified prompt {path}")
        return path
    except Exception as exc:  # noqa: BLE001 - update failures must not block Teach.
        debug(str(exc))
        cached = cached_runtime(root)
        if cached is not None:
            debug(f"using last-known-good prompt {cached}")
            return cached
        return bundled_runtime()


def main() -> int:
    try:
        print(resolve().resolve())
        return 0
    except RuntimeResolutionError as exc:
        print(f"Teach could not load its prompt: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
