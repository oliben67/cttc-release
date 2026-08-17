# releases/linux

Same design as [`../windows/README.md`](../windows/README.md) (read that
first) -- this directory just swaps in Linux's artifact names and a shell
script instead of PowerShell. Unlike Windows, this is **slim-only** (see
`../windows/README.md`'s "Slim vs bundled"): no image tarball is ever
baked in, only the registry reference in `../_repo/image.json`.

```
build-bundle.sh    builds (via ../_shared/build-image.sh) the server image
                 (to keep the registry ref current) and packages
                 CTTC.AppImage
cttc-setup.sh   legacy: used to reassemble a chunked AppImage before Git
                 LFS took over that job -- always a no-op today.
CTTC.AppImage    the built release, committed directly via Git LFS (see
                 ../.gitattributes's *.AppImage pattern) -- no more
                 size-based chunking.
```

Cut a release from `app/`:

```sh
npm run release:linux          # or: task build:release:linux
```

End users: just run `CTTC.AppImage` directly (`chmod +x` if needed) --
nothing to reassemble or extract first.
