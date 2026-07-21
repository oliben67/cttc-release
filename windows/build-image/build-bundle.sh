#!/usr/bin/env bash
# Rebuilds releases/windows/cttc-windows-deploy.zip from source, then splits
# it into <100MB releases/windows/cttc-windows-deploy.zip.partNNN chunks --
# the zip itself is well over GitHub's 100MB single-blob limit, so only the
# chunks (plus prepare-image.ps1, which reassembles them) get committed.
#
# This is the "build-image" side of releases/windows (see its README): it
# ships the actual built image as a tarball, for CTTC's first run to
# `docker load` -- as opposed to ../repo, which points the app at a
# container registry to `docker pull` from instead. Both ultimately hand
# off to the same install-locally-or-over-ssh logic in
# app/lib/server-provision.js; see releases/windows/README.md.
#
# The zip ships three things:
#   1. CTTC Setup.exe    - from app/dist (npm run dist:win), not rebuilt here
#   2. image/            - server image tarball, rebuilt here (docker build + save)
#   3. image/docker-compose.yml - the offline/docker-load compose variant
#
# No SSH key is bundled here -- the app collects the user's own key via its
# setup wizard (or Run Setup) on first run; see app/lib/ssh-key-file.js.
#
# Usage:
#   releases/windows/build-image/build-bundle.sh
#
# Or, to also rebuild the installer first (whenever the client itself
# changed, not just the server image), from app/:
#   npm run release:win
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"
windows_dir="$repo_root/releases/windows"
server_dir="$repo_root/app/server"

installer="$(find "$repo_root/app/dist" -maxdepth 1 -name "CTTC Setup *.exe" ! -name "*.blockmap" | sort -V | tail -1)"
if [[ -z "$installer" ]]; then
  echo "error: no installer found under app/dist -- run 'npm run dist:win' in app/ first" >&2
  exit 1
fi
echo "Using installer: $installer"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

echo "Building server image (docker build, linux/amd64 -- the deploy target's arch)..."
docker build --platform linux/amd64 -t cttc-server:latest "$server_dir"

mkdir -p "$stage/image"
echo "Saving + gzipping image (this can take a minute)..."
docker save cttc-server:latest | gzip > "$stage/image/cttc-server.tar.gz"
cp "$script_dir/docker-compose.yml" "$stage/image/docker-compose.yml"
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
echo "zip itself, which is gitignored). Reassemble with prepare-image.ps1."
docker rmi cttc-server:latest > /dev/null 2>&1 || true
