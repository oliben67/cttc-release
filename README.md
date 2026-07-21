# cttc-release

Built release artifacts for [CTTC](https://github.com/oliben67/cut-to-the-chase),
tracked as a submodule (`releases/`) of the main repo. Kept separate so the
main repo's history never carries large binaries (installers, container
image tarballs).

## Contents

- **`shared/`** -- the server container image, built once and reused across
  every platform below (it's always the same linux/amd64 image regardless
  of the client's host OS). See `shared/build-image.sh`.
- **`repo/`** -- `image.json` + a docker-compose variant for the
  registry-pull path (an alternative to the baked-in tarball -- see
  `windows/README.md`'s "Two ways to get the image").
- **`windows/`** -- packaged as "bundled" (image tarball baked in, always
  chunked) or "slim" (registry reference only, usually fits under GitHub's
  100MB limit directly) -- see `windows/README.md`'s "Slim vs bundled".
- **`macos/`**, **`linux/`** -- slim-only for now (their base Electron
  package alone is already close to/over the 100MB limit).

See [`windows/README.md`](windows/README.md) for the full breakdown -- the
same design applies to all three, just with a different installer format
and a shell script instead of PowerShell for macOS/Linux's
`prepare-setup.sh`.

## For end users

Pick your platform's folder. If the installer (`CTTC Setup.exe` /
`CTTC.dmg` / `CTTC.AppImage`) is sitting there directly, just run/open it
-- nothing else to do. Otherwise download `CTTC Setup.ps1`/
`prepare-setup.sh` and its `cttc-<platform>-deploy.zip.partNNN` files, run
it, then run/open whatever it extracts -- see
[`windows/README.md`](windows/README.md) for what that script actually
does. Nothing else in this repo needs to be downloaded.
