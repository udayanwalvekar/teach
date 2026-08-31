#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
skill_root="$repo/plugins/teach/skills/teach"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/teach-runtime-test.XXXXXX")

cleanup() {
  status=$?
  set +e
  rm -rf "$test_root"
  return "$status"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

remote_root="$test_root/remote"
cache_root="$test_root/cache"
empty_cache="$test_root/empty-cache"
cp -R "$skill_root" "$remote_root"

remote_url=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$remote_root")
resolved_cache=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$cache_root")

resolve() {
  TEACH_UPDATE_BASE_URL="$remote_url" \
  TEACH_CACHE_DIR="$cache_root" \
  python3 "$skill_root/scripts/resolve_runtime.py"
}

first_runtime=$(resolve)
test "$first_runtime" = "$skill_root/runtime/teach.md"
cmp "$first_runtime" "$remote_root/runtime/teach.md"

second_runtime=$(resolve)
test "$second_runtime" = "$first_runtime"

printf '\nRuntime update test marker.\n' >> "$remote_root/runtime/teach.md"
python3 "$remote_root/scripts/build_runtime_manifest.py" >/dev/null
updated_runtime=$(resolve)
test "$updated_runtime" != "$first_runtime"
case "$updated_runtime" in
  "$resolved_cache"/bundles/*/runtime/teach.md) ;;
  *)
    echo "Changed prompt did not use the verified cache: $updated_runtime" >&2
    exit 1
    ;;
esac
grep -F 'Runtime update test marker.' "$updated_runtime" >/dev/null

printf '{"schema_version": 999}\n' > "$remote_root/runtime/manifest.json"
offline_runtime=$(resolve)
test "$offline_runtime" = "$updated_runtime"

printf '\nTampered cache marker.\n' >> "$updated_runtime"
recovered_runtime=$(resolve)
test "$recovered_runtime" = "$first_runtime"

python3 "$remote_root/scripts/build_runtime_manifest.py" >/dev/null
repaired_runtime=$(resolve)
test "$repaired_runtime" = "$updated_runtime"
grep -F 'Runtime update test marker.' "$repaired_runtime" >/dev/null
if grep -F 'Tampered cache marker.' "$repaired_runtime" >/dev/null; then
  echo "Teach did not repair a corrupted current cache bundle." >&2
  exit 1
fi

bundled_runtime=$(TEACH_DISABLE_UPDATES=1 TEACH_CACHE_DIR="$cache_root" python3 "$skill_root/scripts/resolve_runtime.py")
test "$bundled_runtime" = "$skill_root/runtime/teach.md"

missing_url=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$test_root/missing")
fallback_runtime=$(TEACH_UPDATE_BASE_URL="$missing_url" TEACH_CACHE_DIR="$empty_cache" python3 "$skill_root/scripts/resolve_runtime.py")
test "$fallback_runtime" = "$skill_root/runtime/teach.md"

python3 "$skill_root/scripts/build_runtime_manifest.py" --check

echo "Dynamic prompt update, cache, integrity, and fallback checks passed."
