#!/usr/bin/env bash
# Finalizes a built installer for git: copies it directly under its real
# name, no zipping or chunking. Previously split anything over GitHub's
# 100MB single-blob limit into <zip-base>.zip.partNNN chunks; now that
# large binaries (.exe/.zip/.gz/.dmg/.pkg, see ../.gitattributes) are
# tracked via Git LFS, that limit no longer applies -- LFS stores the
# blob outside the normal object store regardless of size. Cleans up any
# zip/chunk files a previous (pre-LFS) run left behind, so switching to
# this script never leaves stale files around.
#
# Usage: finalize-artifact.sh <built-installer-path> <dest-dir> <dest-filename> <zip-base-name>
set -euo pipefail

installer="$1"
dest_dir="$2"
dest_name="$3"
zip_base="$4"

size="$(stat -f%z "$installer" 2>/dev/null || stat -c%s "$installer")"

rm -f "$dest_dir/$dest_name" "$dest_dir/$zip_base.zip" "$dest_dir/$zip_base.zip.part"*

cp "$installer" "$dest_dir/$dest_name"
echo "$dest_name is $((size / 1024 / 1024))MB -- committing it directly via Git LFS, no zip/chunks."
