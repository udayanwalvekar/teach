#!/bin/sh

set -eu

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

if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
  python_command=python3
elif command -v python >/dev/null 2>&1 && python -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
  python_command=python
else
  echo "Teach needs Python 3.9 or newer. Install Python 3, then run this installer again." >&2
  exit 1
fi

detect_agent() {
  override=$1
  command_name=$2
  fallback_path=$3

  case "$override" in
    1|true|yes) return 0 ;;
    0|false|no) return 1 ;;
    auto|'') ;;
    *)
      echo "Invalid Teach installer override: $override" >&2
      exit 2
      ;;
  esac

  if command -v "$command_name" >/dev/null 2>&1; then
    return 0
  fi
  [ -n "$fallback_path" ] && [ -d "$fallback_path" ]
}

codex_detected=false
claude_detected=false

if detect_agent "${TEACH_INSTALL_CODEX:-auto}" codex ""; then
  codex_detected=true
fi
if detect_agent "${TEACH_INSTALL_CLAUDE:-auto}" claude "${HOME}/.claude"; then
  claude_detected=true
fi

if [ "$codex_detected" != true ] && [ "$claude_detected" != true ]; then
  echo "Teach could not find Codex or Claude Code on this computer." >&2
  echo "Install one of those coding agents, then run this same command again." >&2
  exit 1
fi

if [ "$codex_detected" = true ]; then
  echo "Installing Teach for Codex..."
  marketplace_json=$(codex plugin marketplace list --json)
  if printf '%s' "$marketplace_json" | "$python_command" -c 'import json,sys; raise SystemExit(not any(item.get("name") == "teach" for item in json.load(sys.stdin).get("marketplaces", [])))'; then
    codex plugin marketplace upgrade teach >/dev/null
  else
    codex plugin marketplace add udayanwalvekar/teach >/dev/null
  fi

  plugin_json=$(codex plugin list --json)
  if printf '%s' "$plugin_json" | "$python_command" -c 'import json,sys; raise SystemExit(not any(item.get("pluginId") == "teach@teach" and item.get("installed") for item in json.load(sys.stdin).get("installed", [])))'; then
    codex plugin remove teach@teach >/dev/null
  fi
  codex plugin add teach@teach >/dev/null

  marketplace_json=$(codex plugin marketplace list --json)
  codex_marketplace_root=$(printf '%s' "$marketplace_json" | "$python_command" -c 'import json,sys; matches=[item.get("root") for item in json.load(sys.stdin).get("marketplaces", []) if item.get("name") == "teach"]; print(matches[0] if matches else "")')
fi

if [ "$claude_detected" = true ]; then
  echo "Installing Teach for Claude Code..."
  if [ -n "${TEACH_SOURCE_BASE_URL:-}" ]; then
    source_base_url=${TEACH_SOURCE_BASE_URL%/}
  elif [ -n "${codex_marketplace_root:-}" ] && command -v git >/dev/null 2>&1; then
    teach_revision=$(git -C "$codex_marketplace_root" rev-parse HEAD)
    source_base_url="https://raw.githubusercontent.com/udayanwalvekar/teach/$teach_revision"
  else
    revision_metadata="$download_root/revision.json"
    download "https://api.github.com/repos/udayanwalvekar/teach/commits/main" "$revision_metadata"
    teach_revision=$("$python_command" -c 'import json,sys; value=json.load(open(sys.argv[1])).get("sha", ""); print(value); raise SystemExit(len(value) != 40 or any(c not in "0123456789abcdef" for c in value))' "$revision_metadata")
    if [ -z "$teach_revision" ]; then
      echo "Teach could not resolve the current installer revision from GitHub." >&2
      exit 1
    fi
    source_base_url="https://raw.githubusercontent.com/udayanwalvekar/teach/$teach_revision"
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

  if [ -e "${TEACH_CLAUDE_DESTINATION:-${HOME}/.claude/skills/teach}" ]; then
    TEACH_QUIET_INSTALL=1 sh "$installer" --force
  else
    TEACH_QUIET_INSTALL=1 sh "$installer"
  fi
fi

if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
  bold='\033[1m'
  dim='\033[2m'
  reset='\033[0m'

  for frame in '·' '··' '···' '●··' '●●·' '●●●'; do
    printf "\r  %s  ${dim}putting Teach in the right place${reset}" "$frame"
    sleep 0.08
  done
  printf '\r\033[2K'
  printf "\n  ┌──────────────────────────────────────┐\n"
  printf "  │  ${bold}TEACH IS READY${reset}                      │\n"
  printf "  │  you built it. now understand it.    │\n"
  printf "  └──────────────────────────────────────┘\n\n"
  printf "  ${dim}Restart your coding agent. In the build chat, type:${reset}\n\n"
  printf "      ${bold}teach${reset}\n\n"
else
  echo "Teach is ready. Restart your coding agent, return to the build chat, and type: teach"
fi
