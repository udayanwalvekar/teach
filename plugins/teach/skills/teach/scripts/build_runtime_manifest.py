#!/usr/bin/env python3
"""Build or verify the manifest for Teach's dynamically updated prompt files."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = SKILL_ROOT / "runtime" / "manifest.json"
PROMPT_VERSION = 1
BOOTSTRAP_API_VERSION = 1


def prompt_files() -> list[Path]:
    files = list((SKILL_ROOT / "runtime").glob("*.md"))
    files.extend((SKILL_ROOT / "references").glob("*.md"))
    return sorted(files, key=lambda path: path.relative_to(SKILL_ROOT).as_posix())


def build_manifest(prompt_version: int) -> dict[str, object]:
    files = []
    for path in prompt_files():
        files.append(
            {
                "path": path.relative_to(SKILL_ROOT).as_posix(),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
        )
    return {
        "schema_version": 1,
        "prompt_version": prompt_version,
        "minimum_bootstrap_version": 1,
        "bootstrap_api_version": BOOTSTRAP_API_VERSION,
        "files": files,
    }


def serialized_manifest(prompt_version: int) -> str:
    return json.dumps(build_manifest(prompt_version), indent=2, sort_keys=False) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if runtime/manifest.json does not match the prompt files",
    )
    parser.add_argument(
        "--prompt-version",
        type=int,
        default=PROMPT_VERSION,
        help="monotonic integer version for this prompt bundle",
    )
    args = parser.parse_args()
    if args.prompt_version < 1:
        parser.error("--prompt-version must be at least 1")
    expected = serialized_manifest(args.prompt_version)
    if args.check:
        actual = (
            MANIFEST_PATH.read_text(encoding="utf-8") if MANIFEST_PATH.exists() else ""
        )
        if actual != expected:
            print(
                "runtime/manifest.json is stale; run scripts/build_runtime_manifest.py"
            )
            return 1
        return 0
    MANIFEST_PATH.write_text(expected, encoding="utf-8")
    print(MANIFEST_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
