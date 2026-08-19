#!/usr/bin/env bash
# Builds the Windows installer, either "bundled" (the server image tarball
# baked in via electron-builder's extraResources -- works offline, no
# registry needed, but a bigger installer) or "slim" (just a reference to
# the registry image in releases/_repo/image.json -- smaller installer, but
# depends on that registry actually being reachable/published). Then hands
# off to finalize-artifact.sh (same directory), which just copies the
# installer into place under its real name -- releases/windows/ is
# deploy-only (see ../.gitattributes: CTTC Setup.exe is tracked via Git
# LFS, so GitHub's 100MB blob limit doesn't constrain it), this script and
# finalize-artifact.sh live here in _shared/ instead. CTTC needs no
# install-time staging step to find the image either way: it reads its own
# bundled resources directly (see app/lib/server-provision.js).
#
# Usage (from anywhere):
#   releases/_shared/build-bundle.sh [--bundle|--slim] [-c|--reuse-cache] [-c.<path>=<value> ...]
#   (Windows always defaults to --bundle, no prompt -- pass --slim
#   explicitly to override. The shared server image is rebuilt from
#   scratch by default -- pass --reuse-cache to skip that when iterating
#   on packaging only, with no server/ changes at all. Any -c.<path>=<value>
#   argument -- electron-builder's own CLI config-override syntax, e.g.
#   -c.win.azureSignOptions.endpoint=... for code-signing -- is forwarded
#   verbatim to the underlying `npm run dist:win`/`dist:win:slim` call,
#   letting a caller like the signed-release CI workflow inject secrets at
#   build time without ever writing them into a committed config file.
#   Coincidental overlap with this script's own bare -c/--reuse-cache: the
#   two are unambiguous in practice (bash's case matching requires a
#   literal "." after -c for the electron-builder form), but don't confuse
#   them.)
#
# Or via the Task/npm entry point, from app/:
#   npm run release:win        # or: task build:release:win
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
app_dir="$repo_root/app"
dest_dir="$repo_root/releases/windows"

mode=""
image_args=()
builder_args=()
for arg in "$@"; do
  case "$arg" in
    --bundle) mode="bundle" ;;
    --slim) mode="slim" ;;
    -c|--reuse-cache) image_args+=(--reuse-cache) ;;
    -f|--force) ;; # kept as a no-op -- rebuilding is the default now
    -c.*) builder_args+=("$arg") ;;
    *) echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# Windows always ships bundled by default -- no prompt, ever. (Other
# platforms are always slim; see releases/macos and releases/linux's own
# build-bundle.sh, which never had a bundle/slim choice to begin with.)
# Revisit this policy later if per-platform choice is ever wanted again --
# for now --slim is still available as an explicit override.
if [[ -z "$mode" ]]; then
  mode="bundle"
fi

if [[ ${#image_args[@]} -gt 0 ]]; then
  "$repo_root/releases/_shared/build-image.sh" "${image_args[@]}"
else
  "$repo_root/releases/_shared/build-image.sh"
fi

if [[ "$mode" == "bundle" ]]; then
  echo "Building the Windows installer (embeds the shared image as a resource)..."
  if [[ ${#builder_args[@]} -gt 0 ]]; then
    ( cd "$app_dir" && npm run dist:win -- "${builder_args[@]}" )
  else
    ( cd "$app_dir" && npm run dist:win )
  fi
else
  echo "Building the Windows installer (registry image reference only, no bundled tarball)..."
  if [[ ${#builder_args[@]} -gt 0 ]]; then
    ( cd "$app_dir" && npm run dist:win:slim -- "${builder_args[@]}" )
  else
    ( cd "$app_dir" && npm run dist:win:slim )
  fi
fi

installer="$(find "$app_dir/dist" -maxdepth 1 -name "CTTC Setup *.exe" ! -name "*.blockmap" | sort -V | tail -1)"
if [[ -z "$installer" ]]; then
  echo "error: electron-builder did not produce an installer under app/dist" >&2
  exit 1
fi
echo "Using installer: $installer"

"$script_dir/finalize-artifact.sh" "$installer" "$dest_dir" "CTTC Setup.exe" "cttc-windows-deploy"

echo ""
echo "Commit '$dest_dir/CTTC Setup.exe' as-is -- Git LFS (../.gitattributes) handles"
echo "whatever size it ends up, no zipping or chunking needed."
