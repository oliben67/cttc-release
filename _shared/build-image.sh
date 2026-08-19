#!/usr/bin/env bash
# Builds log-sump-extended's image and saves it to
# releases/_shared/log-sump-extended.tar.gz. Shared across all platforms'
# build-bundle.sh (windows/, macos/, linux/): the image itself is
# identical regardless of the client's host OS -- it's always a
# linux/amd64 container image, run via whatever Docker the host has
# (Docker Desktop on Windows/macOS, native Docker on Linux) -- so it only
# needs building once per release, not once per platform.
#
# log-sump-extended (app/log-sump-extended, a separate repo:
# github.com/oliben67/log-sump-extended) is log-sump plus cttc's own
# compat routes, baked in at build time -- its own Dockerfile installs
# log-sump as a real dependency (pinned to a tag) and wires the compat
# routes in via log-sump's create_app(extra_routers=[...]) seam.
# Supersedes the old log-sump-plugin approach (a directory bind-mounted
# into a plain, unmodified log-sump image and dynamically loaded at
# startup) -- see log-sump-extended's own README for why that was
# replaced. Nothing is bind-mounted at deploy time anymore; this is the
# one and only server image cttc ships.
#
# Always rebuilds from scratch: a stale bundled image (missing
# app/log-sump-extended changes released as recently as this same
# session) is a much worse failure mode than a slower release build, and
# Docker's own layer cache already keeps a same-server, different-run
# rebuild fast when nothing actually changed. Pass -c/--reuse-cache to
# explicitly skip rebuilding when log-sump-extended.tar.gz already exists
# (e.g. iterating on electron-builder packaging only, with no server
# changes at all).
#
# Also tags + pushes the image to the registry ref in releases/_repo/image.json
# (best-effort -- see "Registry push" below, but note it's a REAL push: it
# succeeds silently if you're already logged in, not just a no-op dry run).
# The app's default is still the offline tarball baked into each installer
# (not this registry), for two reasons that aren't going away: (1) the
# tarball avoids GitHub's blob-size limit entirely by never needing a
# registry at all, and (2) some corporate networks block pulling from
# container registries outright. The registry path exists as an
# alternative CTTC already knows how to use (see app/lib/server-provision.js
# and Settings > Update server image), so it's kept current from here on
# rather than left as a dead placeholder.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
server_dir="$repo_root/app/log-sump-extended"
image_json="$repo_root/releases/_repo/image.json"
out="$script_dir/log-sump-extended.tar.gz"

# -f/--force is kept as a no-op for anyone with it in muscle memory or a
# script -- rebuilding is the default now, so there's nothing left to force.
reuse_cache=0
for arg in "$@"; do
  case "$arg" in
    -c|--reuse-cache) reuse_cache=1 ;;
    -f|--force) ;;
    *) echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ "$reuse_cache" -eq 1 && -f "$out" ]]; then
  echo "Server image already built at $out (--reuse-cache: skipping rebuild)."
else
  echo "Building log-sump-extended's image (docker build, linux/amd64)..."
  docker build --platform linux/amd64 -f "$server_dir/Dockerfile" -t log-sump-extended:latest "$server_dir"

  echo "Saving + gzipping image (this can take a minute)..."
  docker save log-sump-extended:latest | gzip > "$out"
  echo "Wrote $out"
fi

# The registry push below needs a real, usable Docker daemon (linux/amd64
# image load/tag/push) -- true on every platform this script is normally
# run on (Docker Desktop on Windows/macOS, native Docker on Linux), but
# NOT guaranteed on a Windows CI runner, which may have only Windows-
# container support or no daemon reachable at all. That's fine: a caller
# in that position (the signed-release CI workflow's Windows job) only
# ever needs the offline tarball at $out, already built by an earlier
# Linux job and reused here via --reuse-cache -- the registry push is a
# separate, genuinely optional convenience on top, so skip it outright
# rather than letting `docker load`/`tag`/`push` hard-fail the whole build
# the way they would today (unlike the push itself, these aren't wrapped
# in their own tolerance).
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "docker not available/usable here -- skipping the registry tag/push (the offline tarball at $out is already in place, which is all a downstream electron-builder packaging step needs)." >&2
else
  # A --reuse-cache run skips the build above, so log-sump-extended:latest may
  # not be tagged locally even though $out exists -- load it back from the
  # tarball so the push below always has something to push, every run,
  # regardless of cache state.
  if ! docker image inspect log-sump-extended:latest > /dev/null 2>&1; then
    echo "Loading cached image from $out for the registry push..."
    docker load -i "$out"
  fi

  # -- Registry push (best-effort, but always attempted -- see this script's
  # own module comment: this actually succeeds, and publishes, whenever
  # you're already logged in) -------------------------------------------
  # Requires being logged in to the registry already (Docker Hub by default --
  # `docker login` -- or whatever registry releases/_repo/image.json points
  # at), which isn't assumed here, so a failure is a warning, not a build
  # failure.
  full_ref="$(node -e "const i = require('$image_json'); console.log(\`\${i.image}:\${i.tag}\`)")"
  echo "Tagging + pushing to $full_ref ..."
  docker tag log-sump-extended:latest "$full_ref"
  if docker push "$full_ref"; then
    echo "Pushed $full_ref"
  else
    echo "WARNING: could not push $full_ref -- log in first (docker login) if you want the registry path kept up to date. Continuing with the offline tarball only." >&2
  fi

  docker rmi log-sump-extended:latest > /dev/null 2>&1 || true
fi
