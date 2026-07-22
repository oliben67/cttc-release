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
cttc-setup.sh   the one (and only) script an end user ever runs -- a
                 no-op if CTTC.AppImage is already there directly,
                 otherwise reassembles + extracts it from the .partNNN
                 chunks
CTTC.AppImage    present directly if under GitHub's 100MB limit, OR:
cttc-linux-deploy.zip.partNNN   chunks, only if the AppImage came out too
                 big
```

Cut a release from `app/`:

```sh
npm run release:linux          # or: task build:release:linux
```

End users: if `CTTC.AppImage` is there directly, just run it (`chmod +x`
if needed). Otherwise download `cttc-setup.sh` + the `.partNNN` files,
run `./cttc-setup.sh`, then run the extracted `CTTC.AppImage`.
