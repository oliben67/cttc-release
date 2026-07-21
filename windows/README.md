# releases/windows

Everything needed to get CTTC running on a Windows machine, with the server
running as a container -- either on this same machine (if Docker is
present) or on a separate Docker-enabled host over SSH otherwise. The same
design applies to `../macos/` and `../linux/`; this file is the canonical
writeup, cross-linked from `../README.md`.

## Layout

```
build-bundle.sh    builds (via ../shared/build-image.sh) the server image
                 and packages it into this platform's installer (see "How
                 a release is cut" below)
prepare-setup.ps1  the one (and only) PowerShell an end user ever runs
                 (see below) -- it does NOT install anything itself, and
                 is a no-op if there's nothing to reassemble (see "Slim vs
                 bundled" below)
CTTC Setup.exe   present directly (small enough to commit as-is), OR:
cttc-windows-deploy.zip.partNNN   the built release, chunked for git --
                 only when the installer is too big to commit directly
                 (each part stays under GitHub's 100MB single-blob limit)
```

Shared across all platforms, one level up:

```
../shared/       builds + saves the server image once (identical across
                 Windows/macOS/Linux -- see ../shared/build-image.sh)
../repo/         image.json + docker-compose.yml for the "docker pull from
                 a registry" path (see "Two ways to get the image" below)
```

`cttc-windows-deploy.zip` itself is always gitignored (an intermediate
step, never committed); `CTTC Setup.exe` is gitignored only implicitly --
whether it ends up committed as a plain file or replaced by `.partNNN`
chunks depends on its size at build time (see "Slim vs bundled"). Same
transient treatment for `../shared/cttc-server.tar.gz` -- see "How a
release is cut".

## Slim vs bundled

`build-bundle.sh` asks (or takes `--bundle`/`--slim`) which installer to
build:

- **Bundled** -- the server image tarball is baked into `CTTC Setup.exe`
  (~145MB total). Works fully offline, no registry needed, but is over
  GitHub's 100MB blob limit -- always shipped as `.partNNN` chunks.
- **Slim** -- just the registry reference (`../repo/image.json`) is baked
  in (~95MB). Depends on that registry actually being reachable/published
  (see "Two ways to get the image"), but usually fits under the 100MB
  limit -- committed as `CTTC Setup.exe` directly, no chunking needed.

Either way, `../shared/finalize-artifact.sh` decides for itself based on
the *actual* built size, not just which mode was picked -- if a slim build
somehow ends up over 100MB (or a bundled one somehow under), it still
does the right thing. `../macos/` and `../linux/` are slim-only for now
(their base Electron package is already close to/over the limit even
without any image, so bundling there would make chunking unavoidable).

## Two ways to get the image

CTTC's server always runs as a Docker container. There are two ways the
running app (see `app/lib/server-provision.js`) can get hold of that
container's image:

1. **Offline / docker-load** (`../shared/`) -- the actual image, built and
   `docker save`d ahead of time, baked directly into the installer as an
   electron-builder resource (Windows "bundled" builds only -- see "Slim
   vs bundled" above).
2. **Registry pull** (`../repo/`) -- `image.json` names an image + tag on a
   container registry (e.g. `osteck/cttc-server:0.0.1` on Docker Hub) for
   `docker pull` instead. Every release build now also tags + pushes to
   this ref (see `../shared/build-image.sh`), best-effort -- it requires
   being logged in to the registry, and isn't allowed to fail the release
   if that's not set up. `server-provision.js` prefers a bundled offline
   tarball when the installer has one, falling back to the registry
   otherwise -- which is *always* the case for slim builds (macOS/Linux,
   or a slim Windows build). The offline path exists for two reasons that
   aren't going away: it sidesteps GitHub's blob-size limit entirely (no
   registry needed at all), and some corporate networks block registry
   pulls outright.

## How this all fits together

There's no separate "deploy" step, staging step, or script beyond
`prepare-setup.ps1` (there used to be a `deploy.ps1`, and later a
`prepare-image.ps1` that staged the tarball into `%USERPROFILE%\.cttc\` --
CTTC's own first-run logic replaced both):

1. If `CTTC Setup.exe` isn't already sitting there directly, run
   `prepare-setup.ps1` to reassemble and extract it from the `.partNNN`
   chunks, then delete every build artifact (chunks, the reassembled zip,
   and itself) -- it never runs `CTTC Setup.exe` for you either way.
2. Run `CTTC Setup.exe` yourself, like any normal Windows installer. The
   server image is already inside it, or a registry reference is (see
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
npm run release:win          # or: task release:win
```

(`release:mac` / `release:linux` for the other two platforms -- all three
share the same image build step.) This runs `windows/build-bundle.sh`,
which:
- asks (or takes `--bundle`/`--slim`) whether to bundle the image or just
  reference the registry (see "Slim vs bundled" above),
- builds the server image once via `../shared/build-image.sh`
  (`docker build --platform linux/amd64` against `app/server/`, matching
  the deploy target's usual architecture; skipped if already built --
  pass `--force` to rebuild), `docker save`s + gzips it to
  `../shared/cttc-server.tar.gz` (gitignored -- a build artifact, not
  something to commit), and best-effort tags + pushes it to
  `../repo/image.json`'s registry ref,
- runs `npm run dist:win` (bundled) or `dist:win:slim` (slim) --
  the latter uses `app/electron-builder.win-slim.json` to build without
  the tarball extraResource,
- hands the resulting `CTTC Setup.exe` to `../shared/finalize-artifact.sh`,
  which commits it directly if it's under GitHub's 100MB limit, or zips +
  splits it into `cttc-windows-deploy.zip.partNNN` chunks if not.

Commit whatever `finalize-artifact.sh` produced (`CTTC Setup.exe` directly,
or the `.partNNN` files -- never the intermediate zip, which stays
gitignored either way) in this (`cttc-release`) repo, then bump the
`releases` submodule pointer in the main repo.
