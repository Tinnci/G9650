# G9650 Mainline Kernel Workspace

This is a lightweight control repo for Samsung Galaxy S9+/SM-G9650
star2qltechn/starqltechn kernel work.

Tracked here:

- build wrappers in `scripts/`
- fixed builder image definitions in `docker/`
- upstream pinning in `manifests/`
- curated notes in `docs/`
- our patch series in `patches/`

Not tracked here:

- full Linux kernel source trees
- build output directories
- recovery/kernel images and DTBs
- large logs or temporary artifacts

Default mainline target:

- repo: `https://gitlab.com/dsankouski/sdm845-linux-next.git`
- branch: `6.17-wip/starqltechn_latest_patches`
- pinned head: `f1b20714332646073d4f54190c271917c6da32fa`

Run a dry check:

```sh
DRY_RUN=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

