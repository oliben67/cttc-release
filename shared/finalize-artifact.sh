#!/usr/bin/env bash
# Finalizes a built installer for git: if it already fits under GitHub's
# 100MB single-blob limit, commits it directly under its real name (no
# zip, nothing to reassemble); otherwise zips it and splits that zip into
# <100MB <zip-base>.zip.partNNN chunks, same as before. Cleans up whatever
# the *other* outcome would have left behind, so re-running this after
# switching between bundle/slim (or after the artifact crosses the size
# threshold either way) never leaves stale files from a previous mode.
#
# Usage: finalize-artifact.sh <built-installer-path> <dest-dir> <dest-filename> <zip-base-name>
set -euo pipefail

installer="$1"
dest_dir="$2"
dest_name="$3"
zip_base="$4"
limit=$((100 * 1024 * 1024)) # GitHub's hard single-blob limit

size="$(stat -f%z "$installer" 2>/dev/null || stat -c%s "$installer")"

rm -f "$dest_dir/$dest_name" "$dest_dir/$zip_base.zip" "$dest_dir/$zip_base.zip.part"*

if [[ "$size" -lt "$limit" ]]; then
  cp "$installer" "$dest_dir/$dest_name"
  echo "$dest_name is $((size / 1024 / 1024))MB -- under the 100MB limit, committing it directly (no zip/chunks, nothing to reassemble)."
else
  stage="$(mktemp -d)"
  trap 'rm -rf "$stage"' EXIT
  cp "$installer" "$stage/$dest_name"
  zip_path="$dest_dir/$zip_base.zip"
  ( cd "$stage" && zip -qr "$zip_path" . )
  echo "Wrote $zip_path ($(du -h "$zip_path" | cut -f1)) -- over the 100MB limit, splitting into chunks for git..."
  ( cd "$dest_dir" && split -b 45m -d -a 3 "$zip_base.zip" "$zip_base.zip.part" )
  rm -f "$zip_path"
  echo "Chunks:"
  ls "$dest_dir/$zip_base.zip.part"* | xargs -n1 basename
fi
