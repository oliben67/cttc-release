#!/usr/bin/env bash
# Builds the Windows installer, either "bundled" (the server image tarball
# baked in via electron-builder's extraResources -- works offline, no
# registry needed, but a bigger installer) or "slim" (just a reference to
# the registry image in releases/_repo/image.json -- smaller installer, but
# depends on that registry actually being reachable/published). Then hands
# off to releases/_shared/finalize-artifact.sh, which commits the installer
# directly if it's under GitHub's 100MB blob limit, or zips + chunks it if
# not -- either way CTTC needs no install-time staging step to find the
# image: it reads its own bundled resources directly (see
# app/lib/server-provision.js).
#
# Usage (from anywhere):
#   releases/windows/build-bundle.sh [--bundle|--slim] [-f|--force]
#   (prompts interactively if --bundle/--slim isn't passed; --force rebuilds
#   the shared image even if cached)
#
# Or via the Task/npm entry point, from app/:
#   npm run release:win        # or: task release:win
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
app_dir="$repo_root/app"

mode=""
force=""
for arg in "$@"; do
  case "$arg" in
    --bundle) mode="bundle" ;;
    --slim) mode="slim" ;;
    -f|--force) force="--force" ;;
    *) echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$mode" ]]; then
  read -r -p "Bundle the server image into CTTC Setup.exe? Bigger installer, but works without registry access. [Y/n] " ans
  case "$ans" in
    [nN]*) mode="slim" ;;
    *) mode="bundle" ;;
  esac
fi

"$repo_root/releases/_shared/build-image.sh" $force

if [[ "$mode" == "bundle" ]]; then
  echo "Building the Windows installer (embeds the shared image as a resource)..."
  ( cd "$app_dir" && npm run dist:win )
else
  echo "Building the Windows installer (registry image reference only, no bundled tarball)..."
  ( cd "$app_dir" && npm run dist:win:slim )
fi

installer="$(find "$app_dir/dist" -maxdepth 1 -name "CTTC Setup *.exe" ! -name "*.blockmap" | sort -V | tail -1)"
if [[ -z "$installer" ]]; then
  echo "error: electron-builder did not produce an installer under app/dist" >&2
  exit 1
fi
echo "Using installer: $installer"

"$repo_root/releases/_shared/finalize-artifact.sh" "$installer" "$script_dir" "CTTC Setup.exe" "cttc-windows-deploy"

echo ""
echo "If chunked: commit cttc-windows-deploy.zip.part* (not the zip itself, which is"
echo "gitignored) and reassemble with CTTC Setup.ps1. If committed directly:"
echo "commit 'CTTC Setup.exe' as-is -- nothing to reassemble."
