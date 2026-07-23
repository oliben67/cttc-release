#!/usr/bin/env bash
# Builds the CTTC server image and saves it to releases/_shared/cttc-scout.tar.gz.
# Shared across all platforms' build-bundle.sh (windows/, macos/, linux/):
# the image itself is identical regardless of the client's host OS -- it's
# always a linux/amd64 container image, run via whatever Docker the host
# has (Docker Desktop on Windows/macOS, native Docker on Linux) -- so it
# only needs building once per release, not once per platform.
#
# Skips the rebuild if cttc-scout.tar.gz already exists; pass -f/--force
# to rebuild anyway (e.g. after a server.py change).
#
# Also tags + pushes the image to the registry ref in releases/_repo/image.json
# (best-effort -- see "Registry push" below). The app's default is still the
# offline tarball baked into each installer (not this registry), for two
# reasons that aren't going away: (1) the tarball avoids GitHub's blob-size
# limit entirely by never needing a registry at all, and (2) some corporate
# networks block pulling from container registries outright. The registry
# path exists as an alternative CTTC already knows how to use (see
# app/lib/server-provision.js and Settings > Update server image), so it's
# kept current from here on rather than left as a dead placeholder.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
server_dir="$repo_root/app/server"
image_json="$repo_root/releases/_repo/image.json"
out="$script_dir/cttc-scout.tar.gz"

force=0
[[ "${1:-}" == "-f" || "${1:-}" == "--force" ]] && force=1

if [[ -f "$out" && "$force" -ne 1 ]]; then
  echo "Server image already built at $out (pass --force to rebuild)."
else
  echo "Building server image (docker build, linux/amd64)..."
  docker build --platform linux/amd64 -t cttc-scout:latest "$server_dir"

  echo "Saving + gzipping image (this can take a minute)..."
  docker save cttc-scout:latest | gzip > "$out"
  echo "Wrote $out"
fi

# A cached-tarball run skips the build above, so cttc-scout:latest may not
# be tagged locally even though $out exists -- load it back from the
# tarball so the push below always has something to push, every run,
# regardless of cache state.
if ! docker image inspect cttc-scout:latest > /dev/null 2>&1; then
  echo "Loading cached image from $out for the registry push..."
  docker load -i "$out"
fi

# -- Registry push (best-effort, but always attempted) -----------------------
# Requires being logged in to the registry already (Docker Hub by default --
# `docker login` -- or whatever registry releases/_repo/image.json points
# at), which isn't assumed here, so a failure is a warning, not a build
# failure. CI (see .github/workflows/push-image.yml) logs in first.
full_ref="$(node -e "const i = require('$image_json'); console.log(\`\${i.image}:\${i.tag}\`)")"
echo "Tagging + pushing to $full_ref ..."
docker tag cttc-scout:latest "$full_ref"
if docker push "$full_ref"; then
  echo "Pushed $full_ref"
else
  echo "WARNING: could not push $full_ref -- log in first (docker login <registry>) if you want the registry path kept up to date. Continuing with the offline tarball only." >&2
fi

docker rmi cttc-scout:latest > /dev/null 2>&1 || true
