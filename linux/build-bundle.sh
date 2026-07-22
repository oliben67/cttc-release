#!/usr/bin/env bash
# Builds the Linux AppImage with just a reference to the registry image
# (releases/_repo/image.json) -- no tarball baked in, unlike Windows (the
# shared server image is still built here so the registry ref stays
# current -- see releases/_shared/build-image.sh -- just not embedded).
# releases/_shared/finalize-artifact.sh commits the AppImage directly if
# it's under GitHub's 100MB blob limit, or zips + chunks it if not.
#
# Usage (from anywhere):
#   releases/linux/build-bundle.sh [-f|--force]   # --force rebuilds the shared image even if cached
#
# Or via the Task/npm entry point, from app/:
#   npm run release:linux        # or: task build:release:linux
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
app_dir="$repo_root/app"

"$repo_root/releases/_shared/build-image.sh" "$@"

echo "Building the Linux AppImage (registry image reference only, no bundled tarball)..."
( cd "$app_dir" && npm run dist:linux )

installer="$(find "$app_dir/dist" -maxdepth 1 -name "*.AppImage" | sort -V | tail -1)"
if [[ -z "$installer" ]]; then
  echo "error: dist:linux did not produce an .AppImage under app/dist" >&2
  exit 1
fi
echo "Using AppImage: $installer"

chmod +x "$installer"
"$repo_root/releases/_shared/finalize-artifact.sh" "$installer" "$script_dir" "CTTC.AppImage" "cttc-linux-deploy"
chmod +x "$script_dir/CTTC.AppImage" 2>/dev/null || true

echo ""
echo "If chunked: commit cttc-linux-deploy.zip.part* (not the zip itself, which is"
echo "gitignored) and reassemble with cttc-setup.sh. If committed directly:"
echo "commit 'CTTC.AppImage' as-is -- nothing to reassemble."
