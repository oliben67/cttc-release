# releases/macos

Same design as [`../windows/README.md`](../windows/README.md) (read that
first) -- this directory just swaps in macOS's artifact name. Unlike
Windows, this is **slim-only** (see `../windows/README.md`'s "Slim vs
bundled"): no image tarball is ever baked in, only the registry reference
in `../_repo/image.json`.

This directory is deploy-only -- it holds nothing but what actually ships
to an end user:

```
CTTC.dmg         the built release, committed directly via Git LFS (see
                 ../.gitattributes) -- no size-based chunking.
```

There used to also be a `cttc-setup.sh` here (legacy: reassembled a
chunked .dmg before Git LFS took over that job) and a `build-bundle.sh`
(the build script, not a deployed artifact). Both are gone from this
directory now: the reassembly logic became permanently dead code once
chunking stopped happening at all, so it was removed outright;
`build-bundle.sh` moved to `../_shared/` (it's a build-time tool, not
something an end user needs).

Cut a release from `app/`:

```sh
npm run release:mac          # or: task build:release:mac
```

(Runs `../_shared/build-bundle.sh`, which builds the shared server image,
via `../_shared/build-image.sh`, packages `CTTC.dmg`, and hands it to
`../_shared/finalize-artifact.sh` to commit here.)

`task build:release:mac` wraps that with two more steps (see
`../windows/README.md`'s "Build number + GitHub Releases" for the full
writeup): `../_shared/bump-release-num.sh` bumps this branch's own
`../release-num.txt` first, and after the commit is pushed,
`../_shared/publish-release.sh -mac "CTTC.dmg" ../macos` tags it
`<app-version>-macN` and publishes a GitHub Release on
`oliben67/cttc-release` with `CTTC.zip` (this dir's `CTTC.dmg` +
`README.md`) attached.

End users: just open `CTTC.dmg` directly -- nothing to reassemble or
extract first.
