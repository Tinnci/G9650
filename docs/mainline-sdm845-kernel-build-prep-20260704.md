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
- Docker image id: `sha256:2aa7b9ebf945fa8a603c37a6cb4fc7897679e94e8f474cdbb87696195daf6cdf`
- Docker image size: `379067975` bytes
- branch: `6.17-wip/starqltechn_latest_patches`
- clone depth: `80`
- config flow: `defconfig`, merge `arch/arm64/configs/sdm845.config`,
  then `olddefconfig`
- default targets: `Image.gz qcom/sdm845-samsung-star2qltechn.dtb`
- full DTB target: set `BUILD_ALL_DTBS=1` to build `Image.gz dtbs`
- module target: set `BUILD_MODULES=1` to append `modules`
- `CONFIG_LOCALVERSION_AUTO` is disabled by the wrapper after config merge for
  future builds, because the first build showed slow `git status` checks in
  `scripts/setlocalversion` on the T5 checkout.

Verified builder tools:

- clang: `Ubuntu clang version 18.1.3 (1ubuntu1)`
- lld: `Ubuntu LLD 18.1.3`
- aarch64 gcc: `13.3.0`
- dtc: `1.7.0`
- pahole: `v1.25`
- make: `GNU Make 4.3`
- python: `3.12.3`
- xxd: `/usr/bin/xxd`
- swig: `/usr/bin/swig`

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

Build the full arm64 DTB set:

```sh
BUILD_ALL_DTBS=1 CLONE_KERNEL=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Build the fast G9650 image/DTB plus modules:

```sh
BUILD_MODULES=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
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

## First successful build

This first build is preserved as history. It used the upstream `starqltechn`
target and is not the preferred G9650 recovery test target anymore.

Build record:

- `analysis/mainline-kernel-build-20260704-070427`

Command:

```sh
CLONE_KERNEL=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Actual first-run targets:

- `Image.gz`
- `dtbs`

Artifacts under
`/Volumes/gts7-android-build/android/kernel-builds/sdm845/out-mainline-starqltechn`:

- `arch/arm64/boot/Image.gz`
  - size: `15150013`
  - sha256: `a6afc0b24a1b01f7a239ede43054ecf645404d3c5e795e899f93f0402ce7f8e0`
- `arch/arm64/boot/Image`
  - size: `40614400`
  - sha256: `886102905a02f604612cb42fb4d5829fab115f86d5103d3f62465d57d137318a`
- `arch/arm64/boot/dts/qcom/sdm845-samsung-starqltechn.dtb`
  - size: `112014`
  - sha256: `0911308a1ae8b3096875178f8685ea25f7da2d7aed949f5a7fc27ccfd1e09301`

Log summary:

- `build.log`: `5040` lines
- `merge-config.log`: `3701` lines
- generated DTB list: `351` files
- warnings: `6`
- errors: `0`
- fatal errors: `0`

Warnings were limited to unused variables in DRM panel drivers:

- `panel-lg-sw43408.c`
- `panel-samsung-s6e3ha8.c`

Important config observations from the first build:

- `CONFIG_PCIE_QCOM=y`
- `CONFIG_BT_BCM=m`
- `CONFIG_BT_HCIUART=m`
- `CONFIG_BT_HCIUART_BCM=y`
- `CONFIG_WLAN_VENDOR_BROADCOM=y`
- `CONFIG_BRCMFMAC` is not set

This means the modern mainline branch now compiles for the device target, but it
does not yet include a working Broadcom BCM4361 Wi-Fi driver path.

## Current G9650 debug build

The current default target is the G9650 `star2qltechn` debug DTB:

- build record: `analysis/mainline-kernel-build-20260704-113151`
- output root: `/Volumes/gts7-android-build/android/kernel-builds/sdm845/out-mainline-star2qltechn`
- target DTB: `qcom/sdm845-samsung-star2qltechn.dtb`

Artifacts:

- `arch/arm64/boot/Image.gz`
  - size: `15150776`
  - sha256: `806b7c9d2bdae39459e2b2d52af0da33b5e1d2db7f7b12cf54143f4717a2c891`
- `arch/arm64/boot/Image`
  - size: `40614400`
  - sha256: `70df6db4a5e40c463675114cfea262c450d46616ab113f49925cb406b6691eea`
- `arch/arm64/boot/dts/qcom/sdm845-samsung-star2qltechn.dtb`
  - size: `113242`
  - sha256: `98c8a7a2ad4f13b334f716cf66c5596b3d01d44662970f7296f0d3f261242d22`

Use this build for the next recovery evidence test. See
`docs/mainline-star2qltechn-recovery-debug-build-20260704.md`.

## Wireless follow-up

Compilation alone will not fix wireless. The next narrow porting track still
needs to compare mainline DTS/config with Samsung downstream for:

- BCM4361 Wi-Fi over PCIe RC0
- WLAN enable and OOB host-wake GPIOs
- PCIe RC0 power/link sequencing
- Broadcom Bluetooth over `ttyHS0`/QUP hsuart8
- BT reset, wake, host-wake, and bluesleep GPIOs
- Wi-Fi firmware/NVRAM and BT `.hcd` packaging
