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
prepare-image.ps1  the one thing an end user actually runs (see below)
cttc-windows-deploy.zip.partNNN   the built release, chunked for git (each
                 part stays under GitHub's 100MB single-blob limit)
```

`cttc-windows-deploy.zip` itself, and the folder it extracts to, are
gitignored -- `prepare-image.ps1` reconstitutes and cleans them up, so
they're never meant to be committed.

## Two ways to get the image

CTTC's server always runs as a Docker container. There are two ways the
running app (see `app/lib/server-provision.js`) can get hold of that
container's image:

1. **Offline / docker-load** (`build-image/`) -- the actual image, built
   and `docker save`d ahead of time, shipped as a tarball. This is what's
   in `cttc-windows-deploy.zip` today, and what `prepare-image.ps1` stages
   for CTTC to `docker load`.
2. **Registry pull** (`repo/`) -- `repo/image.json` names an image + tag on
   a container registry (e.g. `ghcr.io/oliben67/cttc-server:0.0.1`) for
   `docker pull` instead. **This path is not live yet** -- `image.json`
   currently holds a placeholder that doesn't correspond to a real
   published image. `server-provision.js` always prefers the staged
   offline tarball when one is present, and only falls back to a registry
   pull otherwise, so nothing breaks once a real registry is wired up --
   until then, ship the offline path (`build-image/`).

## How this all fits together

There's no separate "deploy" step or script (there used to be a
`deploy.ps1`; CTTC's own first-run logic replaced it):

1. `prepare-image.ps1` reassembles and extracts the zip, stages the image
   tarball + its compose file at `%USERPROFILE%\.cttc\offline-image\`,
   silently installs `CTTC Setup.exe`, launches it, then deletes every
   build artifact (chunks, the extracted folder, `build-image/`, and
   itself) -- leaving just the installed app and the staged image behind.
2. On first run, CTTC checks whether the offline image is staged, then:
   - if a local Docker is present, `docker load`s it and runs the
     container locally (`app/lib/server-provision.js`'s local path);
   - otherwise its setup wizard asks for a Docker-enabled host to `ssh`
     into, then provisions (load/pull + `docker compose up`) the container
     *there* before opening its usual ssh-tunnel port-forward.
3. Re-running setup later (File > Preferences > Settings > Run Setup) goes
   through the same logic, and additionally offers "revert to local" if a
   local Docker is now present.

See `docs/architecture/remote-server.md` in the main repo for the deeper
architectural background, and `app/lib/server-provision.js` for the actual
provisioning code.

## How a release is cut

From `app/` in the main repo (needs Docker and, for the installer, the
usual `npm run dist:win` toolchain):

```sh
npm run release:win          # or: task release:win
```

This runs `dist:win` (rebuilds `CTTC Setup.exe`) and then
`build-image/build-bundle.sh`, which:
- builds the server image (`docker build --platform linux/amd64` against
  `app/server/`, matching the deploy target's usual architecture),
- `docker save`s + gzips it,
- zips it up with `CTTC Setup.exe` and `build-image/docker-compose.yml`
  into `cttc-windows-deploy.zip`,
- splits that zip into `cttc-windows-deploy.zip.partNNN` chunks.

Commit and push the `.partNNN` files (not the zip itself, which stays
gitignored) in this (`cttc-release`) repo, then bump the `releases`
submodule pointer in the main repo.
