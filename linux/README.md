# releases/linux

Same design as [`../windows/README.md`](../windows/README.md) (read that
first) -- this directory just swaps in Linux's artifact name. Unlike
Windows, this is **slim-only** (see `../windows/README.md`'s "Slim vs
bundled"): no image tarball is ever baked in, only the registry reference
in `../_repo/image.json`.

This directory is deploy-only -- it holds nothing but what actually ships
to an end user:

```
CTTC.AppImage    the built release, committed directly via Git LFS (see
                 ../.gitattributes's *.AppImage pattern) -- no
                 size-based chunking.
```

There used to also be a `cttc-setup.sh` here (legacy: reassembled a
chunked AppImage before Git LFS took over that job) and a `build-bundle.sh`
(the build script, not a deployed artifact). Both are gone from this
directory now: the reassembly logic became permanently dead code once
chunking stopped happening at all, so it was removed outright;
`build-bundle.sh` moved to `../_shared/` (it's a build-time tool, not
something an end user needs).

Cut a release from `app/`:

```sh
npm run release:linux          # or: task build:release:linux
```

(Runs `../_shared/build-bundle.sh`, which builds the shared server image,
via `../_shared/build-image.sh`, packages `CTTC.AppImage`, and hands it to
`../_shared/finalize-artifact.sh` to commit here.)

End users: just run `CTTC.AppImage` directly (`chmod +x` if needed) --
nothing to reassemble or extract first.
