#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
  exec python3 "$script_dir/resolve_runtime.py"
fi
if command -v python >/dev/null 2>&1 && python -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
  exec python "$script_dir/resolve_runtime.py"
fi

echo "Teach needs Python 3.9 or newer. Install Python 3, then run Teach again." >&2
exit 1
