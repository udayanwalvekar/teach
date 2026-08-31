#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
skill_root="$repo/plugins/teach/skills/teach"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/teach-runtime-test.XXXXXX")

cleanup() {
  status=$?
  set +e
  if [ -n "${server_pid:-}" ]; then
    kill "$server_pid" 2>/dev/null
    wait "$server_pid" 2>/dev/null
  fi
  rm -rf "$test_root"
  return "$status"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

remote_root="$test_root/remote"
cache_root="$test_root/cache"
empty_cache="$test_root/empty-cache"
slow_cache="$test_root/slow-cache"
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
unchanged_version_runtime=$(resolve)
test "$unchanged_version_runtime" = "$first_runtime"

python3 "$remote_root/scripts/build_runtime_manifest.py" --prompt-version 2 >/dev/null
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

python3 "$remote_root/scripts/build_runtime_manifest.py" --prompt-version 2 >/dev/null
repaired_runtime=$(resolve)
test "$repaired_runtime" = "$updated_runtime"
grep -F 'Runtime update test marker.' "$repaired_runtime" >/dev/null
if grep -F 'Tampered cache marker.' "$repaired_runtime" >/dev/null; then
  echo "Teach did not repair a corrupted current cache bundle." >&2
  exit 1
fi

new_install_root="$test_root/new-install"
cp -R "$skill_root" "$new_install_root"
printf '\nNew installer prompt marker.\n' >> "$new_install_root/runtime/teach.md"
python3 "$new_install_root/scripts/build_runtime_manifest.py" --prompt-version 3 >/dev/null
missing_url=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$test_root/missing")
upgraded_offline_runtime=$(TEACH_UPDATE_BASE_URL="$missing_url" TEACH_CACHE_DIR="$cache_root" python3 "$new_install_root/scripts/resolve_runtime.py")
expected_upgraded_runtime=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$new_install_root/runtime/teach.md")
test "$upgraded_offline_runtime" = "$expected_upgraded_runtime"
grep -F 'New installer prompt marker.' "$upgraded_offline_runtime" >/dev/null

port_file="$test_root/slow-server.port"
python3 "$repo/tests/fixtures/slow-runtime-server.py" \
  --root "$remote_root" \
  --port-file "$port_file" \
  --delay 1.0 &
server_pid=$!
attempt=0
while [ ! -s "$port_file" ] && [ "$attempt" -lt 100 ]; do
  sleep 0.02
  attempt=$((attempt + 1))
done
test -s "$port_file"
slow_url="http://127.0.0.1:$(cat "$port_file")"
started_at=$(python3 -c 'import time; print(time.monotonic())')
deadline_runtime=$(TEACH_UPDATE_BASE_URL="$slow_url" TEACH_UPDATE_TIMEOUT_SECONDS=0.35 TEACH_CACHE_DIR="$slow_cache" python3 "$skill_root/scripts/resolve_runtime.py")
finished_at=$(python3 -c 'import time; print(time.monotonic())')
test "$deadline_runtime" = "$skill_root/runtime/teach.md"
python3 -c 'import sys; elapsed=float(sys.argv[2])-float(sys.argv[1]); assert elapsed < 1.5, elapsed' "$started_at" "$finished_at"
kill "$server_pid" 2>/dev/null
wait "$server_pid" 2>/dev/null || true
server_pid=""

bundled_runtime=$(TEACH_DISABLE_UPDATES=1 TEACH_CACHE_DIR="$cache_root" python3 "$skill_root/scripts/resolve_runtime.py")
test "$bundled_runtime" = "$skill_root/runtime/teach.md"

fallback_runtime=$(TEACH_UPDATE_BASE_URL="$missing_url" TEACH_CACHE_DIR="$empty_cache" python3 "$skill_root/scripts/resolve_runtime.py")
test "$fallback_runtime" = "$skill_root/runtime/teach.md"

only_python_bin="$test_root/only-python-bin"
mkdir "$only_python_bin"
real_python=$(command -v python3)
ln -s "$real_python" "$only_python_bin/python"
printf '#!/bin/sh\nexit 127\n' > "$only_python_bin/python3"
chmod +x "$only_python_bin/python3"
launcher_runtime=$(PATH="$only_python_bin:/usr/bin:/bin" TEACH_DISABLE_UPDATES=1 /bin/sh "$skill_root/scripts/resolve_runtime.sh")
test "$launcher_runtime" = "$skill_root/runtime/teach.md"

python3 "$skill_root/scripts/build_runtime_manifest.py" --check

echo "Dynamic prompt update, cache, integrity, and fallback checks passed."
