#!/usr/bin/env bash
# Builds the macOS installer with just a reference to the registry image
# (releases/_repo/image.json) -- no tarball baked in, unlike Windows: the
# base Electron .dmg is small enough on its own to usually land under
# GitHub's 100MB blob limit without needing the offline path at all (the
# shared server image is still built here so the registry ref stays
# current -- see releases/_shared/build-image.sh -- just not embedded).
# releases/_shared/finalize-artifact.sh commits the .dmg directly if it's
# under the limit, or zips + chunks it if not.
#
# Usage (from anywhere):
#   releases/macos/build-bundle.sh [-f|--force]   # --force rebuilds the shared image even if cached
#
# Or via the Task/npm entry point, from app/:
#   npm run release:mac        # or: task release:mac
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
app_dir="$repo_root/app"

"$repo_root/releases/_shared/build-image.sh" "$@"

echo "Building the macOS installer (registry image reference only, no bundled tarball)..."
( cd "$app_dir" && npm run dist:mac )

installer="$(find "$app_dir/dist" -maxdepth 1 -name "*.dmg" | sort -V | tail -1)"
if [[ -z "$installer" ]]; then
  echo "error: dist:mac did not produce a .dmg under app/dist" >&2
  exit 1
fi
echo "Using installer: $installer"

"$repo_root/releases/_shared/finalize-artifact.sh" "$installer" "$script_dir" "CTTC.dmg" "cttc-macos-deploy"

echo ""
echo "If chunked: commit cttc-macos-deploy.zip.part* (not the zip itself, which is"
echo "gitignored) and reassemble with cttc-setup.sh. If committed directly:"
echo "commit 'CTTC.dmg' as-is -- nothing to reassemble."
