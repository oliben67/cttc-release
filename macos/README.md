# releases/macos

Same design as [`../windows/README.md`](../windows/README.md) (read that
first) -- this directory just swaps in macOS's artifact names and a shell
script instead of PowerShell. Unlike Windows, this is **slim-only** (see
`../windows/README.md`'s "Slim vs bundled"): no image tarball is ever
baked in, only the registry reference in `../_repo/image.json`.

```
build-bundle.sh    builds (via ../_shared/build-image.sh) the server image
                 (to keep the registry ref current) and packages CTTC.dmg
cttc-setup.sh   the one (and only) script an end user ever runs -- a
                 no-op if CTTC.dmg is already there directly, otherwise
                 reassembles + extracts it from the .partNNN chunks
CTTC.dmg         present directly if under GitHub's 100MB limit (usually
                 the case), OR:
cttc-macos-deploy.zip.partNNN   chunks, only if the .dmg came out too big
```

Cut a release from `app/`:

```sh
npm run release:mac          # or: task build:release:mac
```

End users: if `CTTC.dmg` is there directly, just open it. Otherwise
download `cttc-setup.sh` + the `.partNNN` files, run `./cttc-setup.sh`,
then open the extracted `CTTC.dmg`.
