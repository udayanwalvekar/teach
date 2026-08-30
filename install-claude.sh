#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_dir="$script_dir/plugins/teach/skills/teach"
destination="${TEACH_CLAUDE_DESTINATION:-${HOME}/.claude/skills/teach}"
force=false

if [ "${1:-}" = "--force" ]; then
  force=true
elif [ "$#" -gt 0 ]; then
  echo "Usage: ./install-claude.sh [--force]" >&2
  exit 2
fi

if [ ! -f "$source_dir/SKILL.md" ]; then
  echo "Teach skill source was not found at $source_dir" >&2
  exit 1
fi

if [ -e "$destination" ] && [ "$force" != true ]; then
  echo "Teach is already installed at $destination" >&2
  echo "Run ./install-claude.sh --force to update it. Your existing copy will be backed up." >&2
  exit 1
fi

destination_parent=$(dirname -- "$destination")
mkdir -p "$destination_parent"

staging_root=$(mktemp -d "${TMPDIR:-/tmp}/teach-claude.XXXXXX")
trap 'rm -rf "$staging_root"' EXIT HUP INT TERM
mkdir "$staging_root/teach"
cp "$source_dir/SKILL.md" "$staging_root/teach/SKILL.md"
for resource_dir in assets examples references scripts; do
  if [ -d "$source_dir/$resource_dir" ]; then
    cp -R "$source_dir/$resource_dir" "$staging_root/teach/$resource_dir"
  fi
done

if [ -e "$destination" ]; then
  backup="${destination}.backup-$(date -u +%Y%m%d%H%M%S)"
  mv "$destination" "$backup"
  echo "Backed up the previous Teach skill to $backup"
fi

mv "$staging_root/teach" "$destination"

echo "Installed Teach for Claude Code at $destination"
echo "Start or restart Claude Code, finish a build chat, then run /teach"
