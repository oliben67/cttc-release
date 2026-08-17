#!/usr/bin/env bash
# Builds the macOS installer with just a reference to the registry image
# (releases/_repo/image.json) -- no tarball baked in, unlike Windows: the
# base Electron .dmg is small enough on its own to usually land under
# GitHub's 100MB blob limit without needing the offline path at all (the
# shared server image is still built here so the registry ref stays
# current -- see releases/_shared/build-image.sh -- just not embedded).
# Hands off to finalize-artifact.sh (same directory), which just copies
# the .dmg into place under its real name -- releases/macos/ is
# deploy-only (see ../.gitattributes: CTTC.dmg is tracked via Git LFS, so
# GitHub's 100MB blob limit doesn't constrain it), this script and
# finalize-artifact.sh live here in _shared/ instead.
#
# Usage (from anywhere):
#   releases/_shared/build-bundle.sh [-c|--reuse-cache]
#   (the shared server image is rebuilt from scratch by default -- pass
#   --reuse-cache to skip that when iterating on packaging only, with no
#   server/ changes at all)
#
# Or via the Task/npm entry point, from app/:
#   npm run release:mac        # or: task build:release:mac
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
app_dir="$repo_root/app"
dest_dir="$repo_root/releases/macos"

"$script_dir/build-image.sh" "$@"

echo "Building the macOS installer (registry image reference only, no bundled tarball)..."
( cd "$app_dir" && npm run dist:mac )

installer="$(find "$app_dir/dist" -maxdepth 1 -name "*.dmg" | sort -V | tail -1)"
if [[ -z "$installer" ]]; then
  echo "error: dist:mac did not produce a .dmg under app/dist" >&2
  exit 1
fi
echo "Using installer: $installer"

"$script_dir/finalize-artifact.sh" "$installer" "$dest_dir" "CTTC.dmg" "cttc-macos-deploy"

echo ""
echo "Commit '$dest_dir/CTTC.dmg' as-is -- Git LFS (../.gitattributes) handles"
echo "whatever size it ends up, no zipping or chunking needed."
