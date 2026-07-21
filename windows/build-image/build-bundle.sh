#!/usr/bin/env bash
# Builds the server image, bakes it into the Windows installer (via
# electron-builder's extraResources -- see app/package.json), then zips
# just that installer and splits it into <100MB
# releases/windows/cttc-windows-deploy.zip.partNNN chunks -- the installer
# is well over GitHub's 100MB single-blob limit, so only the chunks (plus
# prepare-setup.ps1, which reassembles them) get committed.
#
# CTTC needs no install-time staging step to find the image: it reads its
# own bundled resources directly (see app/lib/server-provision.js). That's
# why this has to build the image *before* packaging the installer, not
# after -- unlike the old flow, which zipped the image alongside an
# already-built installer.
#
# Usage (from anywhere):
#   releases/windows/build-image/build-bundle.sh
#
# Or via the Task/npm entry point, from app/:
#   npm run release:win        # or: task release:win
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"
windows_dir="$repo_root/releases/windows"
server_dir="$repo_root/app/server"
app_dir="$repo_root/app"

echo "Building server image (docker build, linux/amd64 -- the deploy target's arch)..."
docker build --platform linux/amd64 -t cttc-server:latest "$server_dir"

echo "Saving + gzipping image (this can take a minute)..."
docker save cttc-server:latest | gzip > "$script_dir/cttc-server.tar.gz"
docker rmi cttc-server:latest > /dev/null 2>&1 || true

echo "Building the Windows installer (embeds the image above as a resource)..."
( cd "$app_dir" && npm run dist:win )

installer="$(find "$app_dir/dist" -maxdepth 1 -name "CTTC Setup *.exe" ! -name "*.blockmap" | sort -V | tail -1)"
if [[ -z "$installer" ]]; then
  echo "error: dist:win did not produce an installer under app/dist" >&2
  exit 1
fi
echo "Using installer: $installer"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp "$installer" "$stage/CTTC Setup.exe"

out="$windows_dir/cttc-windows-deploy.zip"
rm -f "$out" "$windows_dir"/cttc-windows-deploy.zip.part*
( cd "$stage" && zip -qr "$out" . )
echo "Wrote $out ($(du -h "$out" | cut -f1))"

echo "Splitting into <100MB chunks for git..."
( cd "$windows_dir" && split -b 45m -d -a 3 cttc-windows-deploy.zip cttc-windows-deploy.zip.part )
rm -f "$out"
ls "$windows_dir"/cttc-windows-deploy.zip.part* | xargs -n1 basename

echo ""
echo "Chunks are in $windows_dir -- commit cttc-windows-deploy.zip.part* (not the"
echo "zip itself, which is gitignored). Reassemble with prepare-setup.ps1."
