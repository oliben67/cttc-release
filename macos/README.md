# releases/macos

Same design as [`../windows/README.md`](../windows/README.md) (read that
first) -- this directory just swaps in macOS's artifact names and a shell
script instead of PowerShell. Unlike Windows, this is **slim-only** (see
`../windows/README.md`'s "Slim vs bundled"): no image tarball is ever
baked in, only the registry reference in `../_repo/image.json`.

```
build-bundle.sh    builds (via ../_shared/build-image.sh) the server image
                 (to keep the registry ref current) and packages CTTC.dmg
cttc-setup.sh   legacy: used to reassemble a chunked .dmg before Git LFS
                 took over that job -- always a no-op today.
CTTC.dmg         the built release, committed directly via Git LFS (see
                 ../.gitattributes) -- no more size-based chunking.
```

Cut a release from `app/`:

```sh
npm run release:mac          # or: task build:release:mac
```

End users: just open `CTTC.dmg` directly -- nothing to reassemble or
extract first.
