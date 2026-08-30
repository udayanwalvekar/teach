#!/bin/sh

set -eu

destination="${TEACH_CLAUDE_DESTINATION:-${HOME}/.claude/skills/teach}"
download_root=$(mktemp -d "${TMPDIR:-/tmp}/teach-download.XXXXXX")

cleanup() {
  status=$?
  set +e
  rm -rf "$download_root"
  return "$status"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

if command -v curl >/dev/null 2>&1; then
  download() {
    curl -fsSL "$1" -o "$2"
  }
elif command -v wget >/dev/null 2>&1; then
  download() {
    wget -qO "$2" "$1"
  }
else
  echo "Teach needs curl or wget to download from GitHub." >&2
  exit 1
fi

if [ -n "${TEACH_SOURCE_BASE_URL:-}" ]; then
  source_base_url=${TEACH_SOURCE_BASE_URL%/}
else
  release_metadata="$download_root/release.json"
  download "https://data.jsdelivr.com/v1/package/resolve/gh/udayanwalvekar/teach@latest" "$release_metadata"
  release_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9A-Za-z._-]*\)".*/\1/p' "$release_metadata" | head -n 1)
  if ! printf '%s\n' "$release_version" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'; then
    echo "Teach could not resolve a valid release from GitHub." >&2
    exit 1
  fi
  source_base_url="https://cdn.jsdelivr.net/gh/udayanwalvekar/teach@v$release_version"
fi

manifest="$download_root/claude-files.txt"
download "$source_base_url/claude-files.txt" "$manifest"

while IFS= read -r relative_path || [ -n "$relative_path" ]; do
  relative_path=$(printf '%s' "$relative_path" | tr -d '\r')
  case "$relative_path" in
    ""|'#'*) continue ;;
    /*|../*|*/../*|*/..)
      echo "Unsafe path in the Teach download manifest: $relative_path" >&2
      exit 1
      ;;
  esac

  local_path="$download_root/source/$relative_path"
  mkdir -p "$(dirname -- "$local_path")"
  download "$source_base_url/$relative_path" "$local_path"
done < "$manifest"

installer="$download_root/source/install-claude.sh"
if [ ! -f "$installer" ]; then
  echo "The Teach installer was not found in the GitHub download." >&2
  exit 1
fi

if [ -e "$destination" ]; then
  sh "$installer" --force
else
  sh "$installer"
fi
