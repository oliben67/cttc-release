# cttc-release

Built release artifacts for [CTTC](https://github.com/oliben67/cut-to-the-chase),
tracked as a submodule (`releases/`) of the main repo. Kept separate so the
main repo's history never carries large binaries (installers, container
image tarballs).

## Contents

- **`_shared/`** -- the server container image, built once and reused across
  every platform below (it's always the same linux/amd64 image regardless
  of the client's host OS). See `_shared/build-image.sh`.
- **`_repo/`** -- `image.json` + a docker-compose variant for the
  registry-pull path (an alternative to the baked-in tarball -- see
  `windows/README.md`'s "Two ways to get the image").
- **`windows/`** -- packaged as "bundled" (image tarball baked in) or
  "slim" (registry reference only, smaller) -- either way committed
  directly via Git LFS, no chunking -- see `windows/README.md`'s "Slim vs
  bundled". Deploy-only: holds just `CTTC Setup.exe`, nothing build-time
  (see `../_shared/build-bundle.sh`).
- **`macos/`**, **`linux/`** -- slim-only for now (their base Electron
  package alone is already close to/over the 100MB limit).

See [`windows/README.md`](windows/README.md) for the full breakdown -- the
same design applies to all three, just with a different installer format.

## For end users

Pick your platform's folder and run/open the installer sitting there
directly (`CTTC Setup.exe` / `CTTC.dmg` / `CTTC.AppImage`) -- nothing else
to do, nothing else in this repo needs to be downloaded. See
[`windows/README.md`](windows/README.md) for the full breakdown.
