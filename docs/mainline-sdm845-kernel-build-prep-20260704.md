# Mainline SDM845 Kernel Build Prep - 2026-07-04

This workspace is now prepared as a lightweight control repo for the G9650
mainline kernel work.

## Version control policy

Track:

- `scripts/`
- `docker/`
- `docs/`
- `manifests/`
- `patches/`

Ignore:

- full kernel source trees
- build output directories
- kernel/recovery images and DTBs
- large logs and temporary artifacts

The source checkout and build output should stay on the T5, normally under:

- `/Volumes/gts7-android-build/android/kernel-builds/sdm845/`

## Upstream state

Checked on 2026-07-04:

- repo: `https://gitlab.com/dsankouski/sdm845-linux-next.git`
- latest selected branch: `6.17-wip/starqltechn_latest_patches`
- selected head: `f1b20714332646073d4f54190c271917c6da32fa`
- latest selected commit title: `sdm845.config: enable max98512 downstream codec back because fixed`
- fallback branch: `starqltechn_for_xda`
- fallback head: `b3656a6c63a6fb583185f52b8e58d83dabeef427`

Use the 6.17 WIP branch first. Keep the XDA branch only as a known older
fallback/reference.

## Build entry points

Added:

- `docker/sdm845-mainline-kernel-builder/Dockerfile`
- `scripts/kernel/build-mainline-sdm845-kernel.sh`
- `manifests/mainline-sdm845.json`
- `.dockerignore`

Default build behavior:

- Docker image: `tinnci/sdm845-mainline-kernel-builder:ubuntu24.04`
- Docker image id: `sha256:5a062f61f63f0d1026de8b5485de5b27535c718ff755c7a911838dc6e8cb3739`
- Docker image size: `359451607` bytes
- branch: `6.17-wip/starqltechn_latest_patches`
- clone depth: `80`
- config flow: `defconfig`, merge `arch/arm64/configs/sdm845.config`,
  then `olddefconfig`
- targets: `Image.gz dtbs`

Verified builder tools:

- clang: `Ubuntu clang version 18.1.3 (1ubuntu1)`
- lld: `Ubuntu LLD 18.1.3`
- aarch64 gcc: `13.3.0`
- dtc: `1.7.0`
- pahole: `v1.25`
- make: `GNU Make 4.3`
- python: `3.12.3`

Dry run:

```sh
DRY_RUN=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Build or refresh the builder image:

```sh
DOCKER_BUILD_IMAGE=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Clone and build the latest selected branch:

```sh
CLONE_KERNEL=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Fetch and rebuild an existing checkout:

```sh
FETCH_KERNEL=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Fallback to the older XDA branch:

```sh
KERNEL_BRANCH=starqltechn_for_xda \
KERNEL_NAME=mainline-sdm845-linux-next-starqltechn_for_xda \
CLONE_KERNEL=1 \
RUN_DOCKER=1 \
scripts/kernel/build-mainline-sdm845-kernel.sh
```

## Wireless follow-up

Compilation alone will not fix wireless. The next narrow porting track still
needs to compare mainline DTS/config with Samsung downstream for:

- BCM4361 Wi-Fi over PCIe RC0
- WLAN enable and OOB host-wake GPIOs
- PCIe RC0 power/link sequencing
- Broadcom Bluetooth over `ttyHS0`/QUP hsuart8
- BT reset, wake, host-wake, and bluesleep GPIOs
- Wi-Fi firmware/NVRAM and BT `.hcd` packaging
