#!/usr/bin/env bash
# Tags the just-pushed release commit and publishes it as a GitHub Release
# on oliben67/cttc-release, with a CTTC.zip asset (installer + README.md).
# Run as the last step of a build:release:<platform> task (see
# app/Taskfile.yml), after that task has already built the installer,
# committed it, and pushed -- this script only tags/publishes, it doesn't
# build or commit anything itself.
#
# Usage: publish-release.sh <tag-suffix> <installer-filename> <dest-dir>
#   tag-suffix        e.g. -win, -mac, -linux (see the platform matrix in
#                     the release-tasks prompt this implements)
#   installer-filename  e.g. "CTTC Setup.exe", "CTTC.dmg", "CTTC.AppImage"
#   dest-dir           the platform dir the installer + README.md live in,
#                     e.g. ../releases/windows
#
# The tag is <app-version><tag-suffix><n>, e.g. 0.2.0-win4 -- app-version
# comes from app/package.json (NOT releases/_repo/image.json's tag, which
# is the server image's own version, unrelated to the app's). n comes from
# release-num.txt, already bumped by bump-release-num.sh earlier in the
# same task.
#
# Zips the installer + README.md exactly as they sit in dest-dir right
# now: with finalize-artifact.sh no longer zipping/chunking anything (Git
# LFS handles size instead), the committed copy IS the freshly built copy
# -- there's no separate staging copy to prefer over it.
set -euo pipefail

suffix="$1"
installer_name="$2"
dest_dir="$3"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
releases_root="$repo_root/releases"
app_dir="$repo_root/app"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI not found -- required to publish a GitHub Release" >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh CLI is not authenticated (needs contents:write on oliben67/cttc-release) -- run 'gh auth login' first" >&2
  exit 1
fi

n="$(tr -d '[:space:]' < "$releases_root/release-num.txt" 2>/dev/null || true)"
if [[ -z "$n" ]]; then
  echo "error: $releases_root/release-num.txt is missing or empty -- run bump-release-num.sh first" >&2
  exit 1
fi

v="$(node -e "console.log(require('$app_dir/package.json').version)")"
tag="${v}${suffix}${n}"

if git -C "$releases_root" ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  echo "error: tag '$tag' already exists on oliben67/cttc-release -- refusing to clobber it" >&2
  exit 1
fi

if [[ ! -f "$dest_dir/$installer_name" ]]; then
  echo "error: installer not found at $dest_dir/$installer_name" >&2
  exit 1
fi
if [[ ! -f "$dest_dir/README.md" ]]; then
  echo "error: README.md not found at $dest_dir/README.md" >&2
  exit 1
fi

sha="$(git -C "$releases_root" rev-parse HEAD)"
echo "Tagging oliben67/cttc-release@$sha as $tag ..."
git -C "$releases_root" tag "$tag" "$sha"
git -C "$releases_root" push origin "$tag"

zip_dir="$(mktemp -d)"
trap 'rm -rf "$zip_dir"' EXIT
cp "$dest_dir/$installer_name" "$zip_dir/$installer_name"
cp "$dest_dir/README.md" "$zip_dir/README.md"
( cd "$zip_dir" && zip -q "CTTC.zip" "$installer_name" "README.md" )

echo "Creating GitHub Release v$tag ..."
# --generate-notes: without an explicit --notes/--notes-file too, gh release
# create opens an interactive editor prompt for release notes when run from
# a real terminal (task build:release:win always is) -- this task must run
# start-to-finish unattended, so every field gets a default here rather
# than being left for gh to ask about. GitHub's auto-generated notes (the
# same "Generate release notes" button does) are a reasonable default: a
# commit-log summary since the previous tag, not blank/meaningless content.
gh release create "$tag" \
  --repo oliben67/cttc-release \
  --title "v$tag" \
  --target "$sha" \
  --generate-notes \
  "$zip_dir/CTTC.zip"

echo "Published: https://github.com/oliben67/cttc-release/releases/tag/$tag"
