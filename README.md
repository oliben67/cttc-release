# cttc-release

Built release artifacts for [CTTC](https://github.com/oliben67/cut-to-the-chase),
tracked as a submodule (`releases/`) of the main repo. Kept separate so the
main repo's history never carries large binaries (installers, container
image tarballs).

## Contents

- **`windows/`** -- the Windows deployment bundle: a packaged client
  installer plus the server container image, either built ahead of time
  (`windows/build-image/`) or pulled from a registry (`windows/repo/`). See
  [`windows/README.md`](windows/README.md) for the full breakdown of the
  directory layout, how the two image-sourcing paths work, and how a
  release is cut.

## For end users

Download `prepare-setup.ps1` and the `cttc-windows-deploy.zip.partNNN`
files from `windows/`, run `prepare-setup.ps1`, then run the `CTTC
Setup.exe` it extracts -- see [`windows/README.md`](windows/README.md) for
what that actually does. Nothing else in this repo needs to be downloaded.
