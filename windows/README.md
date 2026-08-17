# releases/windows

Everything needed to get CTTC running on a Windows machine, with the server
running as a container -- either on this same machine (if Docker is
present) or on a separate Docker-enabled host over SSH otherwise. The same
design applies to `../macos/` and `../linux/`; this file is the canonical
writeup, cross-linked from `../README.md`.

## Layout

This directory is deploy-only -- it holds nothing but what actually ships
to an end user:

```
CTTC Setup.exe   the built release, committed directly via Git LFS (see
                 ../.gitattributes) -- no size-based chunking.
```

There used to also be a `CTTC Setup.ps1` here (legacy: reassembled a
chunked installer before Git LFS took over that job) and a
`build-bundle.sh` (the build script, not a deployed artifact). Both are
gone from this directory now: the `.ps1` reassembly logic became
permanently dead code once chunking stopped happening at all, so it was
removed outright; `build-bundle.sh` moved to `../_shared/` (see "How a
release is cut" below) since it's a build-time tool, not something an end
user needs.

Shared across all platforms, one level up:

```
../_shared/       builds + saves the server image once (identical across
                 Windows/macOS/Linux -- see ../_shared/build-image.sh),
                 and holds build-bundle.sh (drives this platform's release
                 build) and bump-release-num.sh/publish-release.sh (tag +
                 GitHub Release publishing -- see "How a release is cut")
../_repo/         image.json + docker-compose.yml for the "docker pull from
                 a registry" path (see "Two ways to get the image" below)
../release-num.txt  a per-branch monotonic build counter -- this branch's
                 own count, independent of macos'/linux's (see "How a
                 release is cut")
```

`cttc-windows-deploy.zip` itself is always gitignored (an intermediate
step, never committed, and no longer produced at all now that
`finalize-artifact.sh` doesn't chunk anything -- see "How a release is
cut"). `CTTC Setup.exe` is committed directly regardless of size, tracked
via Git LFS (`../.gitattributes`) rather than a plain git blob -- GitHub's
100MB single-blob limit doesn't apply to LFS objects.

## Slim vs bundled

`../_shared/build-bundle.sh` asks (or takes `--bundle`/`--slim`) which
installer to build:

- **Bundled** -- the server image tarball is baked into `CTTC Setup.exe`
  (~600MB total). Works fully offline, no registry needed.
- **Slim** -- just the registry reference (`../_repo/image.json`) is baked
  in (much smaller). Depends on that registry actually being
  reachable/published (see "Two ways to get the image").

Either way the result is committed the same way: directly, via Git LFS --
size no longer determines *how* it's committed, only how big the LFS
object ends up. `../macos/` and `../linux/` are slim-only for now (no
particular reason beyond "that's what shipped first" -- LFS removed the
size pressure that used to make bundling there unattractive).

## Two ways to get the image

CTTC's server always runs as a Docker container (log-sump-extended --
log-sump plus cttc's own compat routes, baked in at build time; see
`app/log-sump-extended` in the main repo). There are two ways the running
app (see `app/lib/server-provision.js`) can get hold of that container's
image:

1. **Offline / docker-load** (`../_shared/`) -- the actual image, built and
   `docker save`d ahead of time, baked directly into the installer as an
   electron-builder resource (Windows "bundled" builds only -- see "Slim
   vs bundled" above).
2. **Registry pull** (`../_repo/`) -- `image.json` names an image + tag on a
   container registry (e.g. `osteck/log-sump-extended:0.1.0` on Docker
   Hub) for `docker pull` instead. Every release build now also tags +
   pushes to this ref (see `../_shared/build-image.sh`), best-effort -- it
   requires being logged in to the registry, and isn't allowed to fail the
   release if that's not set up. `server-provision.js` prefers a bundled
   offline tarball when the installer has one, falling back to the
   registry otherwise -- which is *always* the case for slim builds
   (macOS/Linux, or a slim Windows build). The offline path exists for two
   reasons that aren't going away: it works with no network access at all
   once downloaded, and some corporate networks block registry pulls
   outright.

## How this all fits together

There's no separate "deploy" step, staging step, or script:

1. Run `CTTC Setup.exe` directly, like any normal Windows installer --
   nothing to reassemble or extract first. (A `CTTC Setup.ps1` used to
   ship alongside it for exactly that reassembly, back when installers
   over 100MB shipped as `.partNNN` chunks; once Git LFS started tracking
   `CTTC Setup.exe` directly, that script never had anything left to do,
   so it was removed.)
2. The server image is already inside it, or a registry reference is (see
   "Two ways to get the image" above) -- nothing else needs installing or
   copying first.
3. On first run, CTTC reads its own bundled resources and:
   - if a local Docker is present, loads/pulls the image and runs the
     container locally (`app/lib/server-provision.js`'s local path);
   - otherwise its setup wizard asks for a Docker-enabled host to `ssh`
     into, then provisions (load/pull + `docker compose up`) the container
     *there* before opening its usual ssh-tunnel port-forward.
4. Re-running setup later (File > Preferences > Settings > Run Setup) goes
   through the same logic, and additionally offers "revert to local" if a
   local Docker is now present. Settings > "Update server image" pushes a
   *different* image (by registry ref or a local `.tar.gz`) to wherever the
   server currently runs, without re-running the installer.

See `docs/architecture/remote-server.md` in the main repo for the deeper
architectural background, and `app/lib/server-provision.js` for the actual
provisioning code.

## How a release is cut

From `app/` in the main repo (needs Docker and the usual electron-builder
toolchain):

```sh
npm run release:win          # or: task build:release:win
```

(`release:mac` / `release:linux` for the other two platforms -- all three
share the same image build step.) This runs `../_shared/build-bundle.sh`,
which:
- asks (or takes `--bundle`/`--slim`) whether to bundle the image or just
  reference the registry (see "Slim vs bundled" above),
- builds the server image once via `../_shared/build-image.sh`
  (`docker build --platform linux/amd64` against `app/log-sump-extended/`
  -- see that project's own Dockerfile; skipped if `../_shared/log-sump-extended.tar.gz`
  already exists -- pass `--reuse-cache` to skip rebuilding), `docker
  save`s + gzips it to `../_shared/log-sump-extended.tar.gz` (gitignored --
  a build artifact, not something to commit), and best-effort tags +
  pushes it to `../_repo/image.json`'s registry ref,
- runs `npm run dist:win` (bundled) or `dist:win:slim` (slim) --
  the latter uses `app/electron-builder.win-slim.json` to build without
  the tarball extraResource,
- hands the resulting `CTTC Setup.exe` to `../_shared/finalize-artifact.sh`,
  which just copies it into place under its real name -- no zipping,
  no chunking. Git LFS (`../.gitattributes` tracks `*.exe`) handles
  whatever size it ends up.

Commit `CTTC Setup.exe` in this (`cttc-release`) repo, then bump the
`releases` submodule pointer in the main repo.

## Build number + GitHub Releases

`task build:release:win` (and `:mac`/`:linux`) wraps the above with two
more steps, both in `app/Taskfile.yml`:

1. **Before** building: `../_shared/bump-release-num.sh` increments
   `../release-num.txt` by 1 (missing/empty reads as 0, so the first ever
   run yields 1) and writes it back -- this branch's own counter, not
   shared with `macos`/`linux` (each is an independent branch history
   here, so a truly shared counter would need extra cross-branch
   plumbing; not worth it for a build number).
2. **After** committing + pushing the rebuilt `CTTC Setup.exe`:
   `../_shared/publish-release.sh -win "CTTC Setup.exe" ../windows` reads
   the app version `V` from `app/package.json` and the just-bumped `n`,
   tags this repo's `HEAD` as `V-winN` (e.g. `0.2.0-win4`), pushes the
   tag, and creates a GitHub Release titled `vV-winN` on
   `oliben67/cttc-release` with a `CTTC.zip` (containing `CTTC Setup.exe`
   + `README.md`, zipped fresh from what's sitting in this directory)
   attached as the release asset. Requires `gh` authenticated with
   `contents: write` on `cttc-release`; fails loudly rather than
   publishing silently-skipped if it isn't. Refuses to clobber a tag that
   already exists.
