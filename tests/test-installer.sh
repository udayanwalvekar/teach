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
installed_runtime=$(TEACH_DISABLE_UPDATES=1 python3 "$test_home/.claude/skills/teach/scripts/resolve_runtime.py")
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
expected_revision=$(git -C "$repo" rev-parse HEAD)
grep -F "https://raw.githubusercontent.com/udayanwalvekar/teach/$expected_revision/claude-files.txt" "$curl_log" >/dev/null
backup_count=$(find "$test_home/.claude/skills" -maxdepth 1 -type d -name 'teach.backup-*' | wc -l | tr -d ' ')
test "$backup_count" -eq 1

echo "Universal installer fresh-install and update checks passed."
