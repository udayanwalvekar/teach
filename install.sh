#!/bin/sh

set -eu

download_root=$(mktemp -d "${TMPDIR:-/tmp}/teach-download.XXXXXX")
status_file="$download_root/status"
result_file="$download_root/result"
log_file="$download_root/install.log"
install_pid=""
cursor_hidden=false
worker_process=false

cleanup() {
  status=$?
  set +e
  if [ "$worker_process" = true ]; then
    return "$status"
  fi
  if [ -n "$install_pid" ]; then
    kill "$install_pid" 2>/dev/null
    wait "$install_pid" 2>/dev/null
  fi
  if [ "$cursor_hidden" = true ]; then
    printf '\033[?25h'
  fi
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

tui_enabled=false
if [ "${TEACH_FORCE_TUI:-}" = 1 ] || { [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; }; then
  tui_enabled=true
fi

set_status() {
  phase=$1
  if [ "$tui_enabled" = true ]; then
    printf '%s\n' "$phase" > "$status_file"
  else
    printf '%s...\n' "$phase"
  fi
  if [ -n "${TEACH_TEST_PHASE_DELAY:-}" ]; then
    sleep "$TEACH_TEST_PHASE_DELAY"
  fi
}

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

perform_install() {
  set_status "Detecting coding agents"

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
    return 1
  fi

  if [ "$codex_detected" = true ] && [ "$claude_detected" = true ]; then
    printf '%s\n' "Codex + Claude Code" > "$result_file"
  elif [ "$codex_detected" = true ]; then
    printf '%s\n' "Codex" > "$result_file"
  else
    printf '%s\n' "Claude Code" > "$result_file"
  fi

  if [ "$codex_detected" = true ]; then
    set_status "Installing for Codex"
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
    set_status "Installing for Claude Code"
    source_root=""
    source_base_url=""
    if [ -n "${TEACH_SOURCE_BASE_URL:-}" ]; then
      source_base_url=${TEACH_SOURCE_BASE_URL%/}
    elif [ -n "${codex_marketplace_root:-}" ] && [ -f "$codex_marketplace_root/claude-files.txt" ]; then
      source_root=$codex_marketplace_root
    else
      release_metadata="$download_root/release.json"
      download "https://api.github.com/repos/udayanwalvekar/teach/releases/latest" "$release_metadata"
      teach_release=$("$python_command" -c 'import json,re,sys; value=json.load(open(sys.argv[1])).get("tag_name", ""); print(value); raise SystemExit(not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?", value))' "$release_metadata")
      if [ -z "$teach_release" ]; then
        echo "Teach could not resolve the latest release from GitHub." >&2
        return 1
      fi
      source_base_url="https://raw.githubusercontent.com/udayanwalvekar/teach/$teach_release"
    fi

    manifest="$download_root/claude-files.txt"
    if [ -n "$source_root" ]; then
      cp "$source_root/claude-files.txt" "$manifest"
    else
      download "$source_base_url/claude-files.txt" "$manifest"
    fi

    while IFS= read -r relative_path || [ -n "$relative_path" ]; do
      relative_path=$(printf '%s' "$relative_path" | tr -d '\r')
      case "$relative_path" in
        ""|'#'*) continue ;;
        /*|../*|*/../*|*/..)
          echo "Unsafe path in the Teach download manifest: $relative_path" >&2
          return 1
          ;;
      esac

      local_path="$download_root/source/$relative_path"
      mkdir -p "$(dirname -- "$local_path")"
      if [ -n "$source_root" ]; then
        if [ ! -f "$source_root/$relative_path" ]; then
          echo "The Teach marketplace is missing: $relative_path" >&2
          return 1
        fi
        cp "$source_root/$relative_path" "$local_path"
      else
        download "$source_base_url/$relative_path" "$local_path"
      fi
    done < "$manifest"

    installer="$download_root/source/install-claude.sh"
    if [ ! -f "$installer" ]; then
      echo "The Teach installer was not found in the GitHub download." >&2
      return 1
    fi

    if [ -e "${TEACH_CLAUDE_DESTINATION:-${HOME}/.claude/skills/teach}" ]; then
      TEACH_QUIET_INSTALL=1 sh "$installer" --force
    else
      TEACH_QUIET_INSTALL=1 sh "$installer"
    fi
  fi

  set_status "Finishing"
}

show_success() {
  installed_for=$(cat "$result_file")
  if [ "$tui_enabled" = true ]; then
    printf '\n  \033[1m✓ Teach installed\033[0m\n'
    printf '    %s\n\n' "$installed_for"
    printf '    Restart your coding agent, then type: \033[1mteach\033[0m\n\n'
  else
    printf 'Teach is installed for %s. Restart your coding agent, then type: teach\n' "$installed_for"
  fi
}

if [ "$tui_enabled" = true ]; then
  : > "$status_file"
  : > "$log_file"
  printf '\033[?25l'
  cursor_hidden=true

  (worker_process=true; perform_install) > "$log_file" 2>&1 &
  install_pid=$!
  frame_index=0
  while kill -0 "$install_pid" 2>/dev/null; do
    current_status=$(sed -n '1p' "$status_file")
    [ -n "$current_status" ] || current_status="Starting Teach"
    case "$frame_index" in
      0) frame='⠋' ;; 1) frame='⠙' ;; 2) frame='⠹' ;; 3) frame='⠸' ;; 4) frame='⠼' ;;
      5) frame='⠴' ;; 6) frame='⠦' ;; 7) frame='⠧' ;; 8) frame='⠇' ;; *) frame='⠏' ;;
    esac
    frame_index=$(((frame_index + 1) % 10))
    printf '\r\033[2K  %s  %s' "$frame" "$current_status"
    sleep "${TEACH_SPINNER_INTERVAL:-0.08}"
  done

  if wait "$install_pid"; then
    install_status=0
  else
    install_status=$?
  fi
  install_pid=""
  printf '\r\033[2K\033[?25h'
  cursor_hidden=false

  if [ "$install_status" -ne 0 ]; then
    printf '\n  Teach could not be installed.\n\n' >&2
    cat "$log_file" >&2
    exit "$install_status"
  fi
  show_success
else
  perform_install
  show_success
fi
