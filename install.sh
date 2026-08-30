#!/bin/sh

set -eu

source_base_url="${TEACH_SOURCE_BASE_URL:-https://cdn.jsdelivr.net/gh/udayanwalvekar/teach@main}"
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
