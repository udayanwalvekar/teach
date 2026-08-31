#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/teach-installer-test.XXXXXX")

cleanup() {
  status=$?
  set +e
  rm -rf "$test_root"
  return "$status"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

test_home="$test_root/home"
codex_state="$test_root/codex-state"
curl_log="$test_root/curl.log"
mkdir -p "$test_home" "$codex_state"
: > "$curl_log"

run_installer() {
  HOME="$test_home" \
  PATH="$repo/tests/fixtures:$PATH" \
  TEACH_TEST_CODEX_STATE="$codex_state" \
  TEACH_TEST_CURL_LOG="$curl_log" \
  TEACH_TEST_REPO="$repo" \
  TEACH_INSTALL_CODEX=1 \
  TEACH_INSTALL_CLAUDE=1 \
  TERM=dumb \
  sh "$repo/install.sh"
}

first_output=$(run_installer)
printf '%s\n' "$first_output" | grep -F 'type: teach' >/dev/null
test -f "$codex_state/marketplace"
test -f "$codex_state/plugin"
test -f "$test_home/.claude/skills/teach/SKILL.md"
test -f "$test_home/.claude/skills/teach/runtime/manifest.json"
test -f "$test_home/.claude/skills/teach/runtime/teach.md"
test -f "$test_home/.claude/skills/teach/scripts/resolve_runtime.py"
test -f "$test_home/.claude/skills/teach/scripts/resolve_runtime.ps1"
test -f "$test_home/.claude/skills/teach/scripts/resolve_runtime.sh"
grep -F '${CLAUDE_SKILL_DIR}' "$test_home/.claude/skills/teach/SKILL.md" >/dev/null
installed_runtime=$(TEACH_DISABLE_UPDATES=1 sh "$test_home/.claude/skills/teach/scripts/resolve_runtime.sh")
expected_installed_runtime=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$test_home/.claude/skills/teach/runtime/teach.md")
test "$installed_runtime" = "$expected_installed_runtime"
if grep -F 'disable-model-invocation: true' "$test_home/.claude/skills/teach/SKILL.md" >/dev/null; then
  echo "Claude install still disables the bare teach invocation." >&2
  exit 1
fi

second_output=$(run_installer)
printf '%s\n' "$second_output" | grep -F 'type: teach' >/dev/null
grep -F 'plugin marketplace upgrade teach' "$codex_state/actions" >/dev/null
grep -F 'plugin remove teach@teach' "$codex_state/actions" >/dev/null
add_count=$(grep -c '^plugin marketplace add udayanwalvekar/teach$' "$codex_state/actions")
upgrade_count=$(grep -c '^plugin marketplace upgrade teach$' "$codex_state/actions")
test "$add_count" -eq 1
test "$upgrade_count" -eq 1
if grep -F 'data.jsdelivr.com' "$curl_log" >/dev/null; then
  echo "Universal installer resolved Claude from a different release channel." >&2
  exit 1
fi
if [ -s "$curl_log" ]; then
  echo "Combined install should reuse the refreshed local Codex marketplace for Claude." >&2
  exit 1
fi
backup_count=$(find "$test_home/.claude/skills" -maxdepth 1 -type d -name 'teach.backup-*' | wc -l | tr -d ' ')
test "$backup_count" -eq 1

claude_only_home="$test_root/claude-only-home"
mkdir -p "$claude_only_home"
: > "$curl_log"
HOME="$claude_only_home" \
PATH="$repo/tests/fixtures:$PATH" \
TEACH_TEST_CURL_LOG="$curl_log" \
TEACH_TEST_REPO="$repo" \
TEACH_INSTALL_CODEX=0 \
TEACH_INSTALL_CLAUDE=1 \
TERM=dumb \
sh "$repo/install.sh" >/dev/null
test -f "$claude_only_home/.claude/skills/teach/SKILL.md"
grep -Fx 'https://api.github.com/repos/udayanwalvekar/teach/releases/latest' "$curl_log" >/dev/null
grep -Fx 'https://raw.githubusercontent.com/udayanwalvekar/teach/v0.6.1/claude-files.txt' "$curl_log" >/dev/null

echo "Universal installer fresh-install and update checks passed."
