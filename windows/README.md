# releases/windows

Everything needed to get CTTC running on a Windows machine, with the server
running as a container -- either on this same machine (if Docker is
present) or on a separate Docker-enabled host over SSH otherwise.

## Layout

```
build-image/    builds the server image from source and packages it as a
                 tarball (see "How a release is cut" below) -- this is the
                 "offline" / docker-load path
repo/            image.json + docker-compose.yml for the "docker pull from a
                 registry" path (see "Two ways to get the image" below)
prepare-setup.ps1  the one (and only) PowerShell an end user ever runs
                 (see below) -- it does NOT install anything itself
cttc-windows-deploy.zip.partNNN   the built release (just the installer,
                 chunked for git -- each part stays under GitHub's 100MB
                 single-blob limit)
```

`cttc-windows-deploy.zip` itself, and the `CTTC Setup.exe` it extracts
(directly into this directory, not a nested folder), are gitignored --
`prepare-setup.ps1` reconstitutes the zip and cleans it back up, so
they're never meant to be committed. Same for `build-image/cttc-server.tar.gz`
-- see "How a release is cut".

## Two ways to get the image

CTTC's server always runs as a Docker container. There are two ways the
running app (see `app/lib/server-provision.js`) can get hold of that
container's image:

1. **Offline / docker-load** (`build-image/`) -- the actual image, built
   and `docker save`d ahead of time, baked directly into the installer as
   an electron-builder resource (see `app/package.json`'s
   `build.extraResources`). This is the path in use today.
2. **Registry pull** (`repo/`) -- `repo/image.json` names an image + tag on
   a container registry (e.g. `ghcr.io/oliben67/cttc-server:0.0.1`) for
   `docker pull` instead. **This path is not live yet** -- `image.json`
   currently holds a placeholder that doesn't correspond to a real
   published image. `server-provision.js` always prefers the bundled
   offline tarball when the installer was built with one, and only falls
   back to a registry pull otherwise, so nothing breaks once a real
   registry is wired up.

## How this all fits together

There's no separate "deploy" step, staging step, or script beyond
`prepare-setup.ps1` (there used to be a `deploy.ps1`, and later a
`prepare-image.ps1` that staged the tarball into `%USERPROFILE%\.cttc\` --
CTTC's own first-run logic replaced both):

1. `prepare-setup.ps1` reassembles and extracts the zip, deletes every
   build artifact (chunks, the reassembled zip, `build-image/`, and
   itself), and stops there -- it never runs `CTTC Setup.exe` for you.
2. Run the extracted `CTTC Setup.exe` yourself, like any normal Windows
   installer. The server image is already inside it (see "Two ways to get
   the image" above) -- nothing else needs installing or copying first.
3. On first run, CTTC reads its own bundled resources and:
   - if a local Docker is present, `docker load`s the bundled image and
     runs the container locally (`app/lib/server-provision.js`'s local
     path);
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

From `app/` in the main repo (needs Docker and the usual `npm run dist:win`
toolchain):

```sh
npm run release:win          # or: task release:win
```

This runs `build-image/build-bundle.sh`, which:
- builds the server image (`docker build --platform linux/amd64` against
  `app/server/`, matching the deploy target's usual architecture),
- `docker save`s + gzips it to `build-image/cttc-server.tar.gz` (gitignored
  -- a build artifact, not something to commit),
- runs `npm run dist:win`, which bakes that tarball (plus both compose
  files and `repo/image.json`) into `CTTC Setup.exe` via electron-builder's
  `extraResources` -- this is why the image has to be built *before* the
  installer, not after,
- zips just that installer into `cttc-windows-deploy.zip`,
- splits that zip into `cttc-windows-deploy.zip.partNNN` chunks.

Commit and push the `.partNNN` files (not the zip itself, which stays
gitignored) in this (`cttc-release`) repo, then bump the `releases`
submodule pointer in the main repo.
