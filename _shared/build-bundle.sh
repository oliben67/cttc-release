#!/usr/bin/env bash
# Builds the Linux AppImage with just a reference to the registry image
# (releases/_repo/image.json) -- no tarball baked in, unlike Windows (the
# shared server image is still built here so the registry ref stays
# current -- see releases/_shared/build-image.sh -- just not embedded).
# Hands off to finalize-artifact.sh (same directory), which just copies
# the AppImage into place under its real name -- releases/linux/ is
# deploy-only (see ../.gitattributes: CTTC.AppImage is tracked via Git
# LFS, so GitHub's 100MB blob limit doesn't constrain it), this script and
# finalize-artifact.sh live here in _shared/ instead.
#
# Usage (from anywhere):
#   releases/_shared/build-bundle.sh [-c|--reuse-cache]
#   (the shared server image is rebuilt from scratch by default -- pass
#   --reuse-cache to skip that when iterating on packaging only, with no
#   server/ changes at all)
#
# Or via the Task/npm entry point, from app/:
#   npm run release:linux        # or: task build:release:linux
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
app_dir="$repo_root/app"
dest_dir="$repo_root/releases/linux"

"$script_dir/build-image.sh" "$@"

echo "Building the Linux AppImage (registry image reference only, no bundled tarball)..."
( cd "$app_dir" && npm run dist:linux )

installer="$(find "$app_dir/dist" -maxdepth 1 -name "*.AppImage" | sort -V | tail -1)"
if [[ -z "$installer" ]]; then
  echo "error: dist:linux did not produce an .AppImage under app/dist" >&2
  exit 1
fi
echo "Using AppImage: $installer"

chmod +x "$installer"
"$script_dir/finalize-artifact.sh" "$installer" "$dest_dir" "CTTC.AppImage" "cttc-linux-deploy"
chmod +x "$dest_dir/CTTC.AppImage" 2>/dev/null || true

echo ""
echo "Commit '$dest_dir/CTTC.AppImage' as-is -- Git LFS (../.gitattributes) handles"
echo "whatever size it ends up, no zipping or chunking needed."
