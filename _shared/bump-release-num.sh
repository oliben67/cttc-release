#!/usr/bin/env bash
# Bumps the monotonic build counter at releases/release-num.txt (this
# repo's own root) by exactly 1 and writes it back. Missing/empty file
# reads as 0, so the first ever bump yields 1. Run once per
# build:release:<platform> task, before the installer is built, so the
# bumped value lands in that task's own "rebuild deploy bundle" commit
# (see app/Taskfile.yml) -- publish-release.sh re-reads the file rather
# than being handed the value directly, since each Task cmds: line is its
# own subprocess and can't share a shell variable with this one.
#
# Deliberately per-platform, not a cross-branch shared sequence: windows/
# mac/linux are three independent branch histories in this repo (see
# ../.gitattributes and this repo's own README), so each keeps its own
# release-num.txt rather than one requiring extra plumbing to stay synced
# across branches.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
releases_root="$(cd "$script_dir/.." && pwd)"
file="$releases_root/release-num.txt"

n=0
if [[ -f "$file" ]]; then
  raw="$(tr -d '[:space:]' < "$file")"
  [[ -n "$raw" ]] && n="$raw"
fi

n=$((n + 1))
echo "$n" > "$file"
echo "release build number: $n"
