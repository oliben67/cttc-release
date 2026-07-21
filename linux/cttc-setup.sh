#!/usr/bin/env bash
# If "CTTC.AppImage" is already sitting next to this script (small enough
# to commit directly -- see releases/_shared/finalize-artifact.sh), there's
# nothing to do. Otherwise reassembles cttc-linux-deploy.zip.partNNN chunks
# (split so no single file exceeds GitHub's 100MB blob limit) back into the
# real zip, extracts it, then cleans up everything only needed to get
# there -- the chunks, the reassembled zip, and (best-effort) this script
# itself -- leaving just "CTTC.AppImage" behind.
#
# This script does NOT install or run anything. That's deliberate: no
# script beyond this one is ever used -- run "CTTC.AppImage" yourself
# (already chmod +x'd for you). From there CTTC handles everything itself:
# the server image is a registry reference already baked in (see
# app/lib/server-provision.js), so there's no separate staging or deploy
# step left to run.
#
# Usage: from a terminal, in the same directory as this script:
#   ./cttc-setup.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
zip_name="cttc-linux-deploy.zip"
zip_path="$root/$zip_name"
appimage_path="$root/CTTC.AppImage"

if [[ -f "$appimage_path" ]]; then
  chmod +x "$appimage_path"
  echo "'$appimage_path' is already here -- nothing to reassemble. Run it to launch CTTC."
  rm -f "$root/$(basename "${BASH_SOURCE[0]}")" 2>/dev/null || true
  exit 0
fi

shopt -s nullglob
parts=("$root/$zip_name".part*)
if [[ ${#parts[@]} -eq 0 ]]; then
  echo "ERROR: no '$appimage_path' and no $zip_name.partNNN chunks found next to this script." >&2
  exit 1
fi

echo "Reassembling ${#parts[@]} chunk(s) into $zip_name ..."
cat "${parts[@]}" > "$zip_path"
echo "Wrote $zip_path ($(du -h "$zip_path" | cut -f1))"

echo "Extracting to $root ..."
unzip -oq "$zip_path" -d "$root"
chmod +x "$appimage_path"

echo "Cleaning up build artifacts..."
rm -f "$zip_path" "${parts[@]}"

echo ""
echo "Done. Run '$appimage_path' to launch CTTC."

# Best-effort self-delete -- harmless if it fails (e.g. read-only mount).
rm -f "$root/$(basename "${BASH_SOURCE[0]}")" 2>/dev/null || true
