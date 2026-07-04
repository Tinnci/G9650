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
- builder image: `tinnci/sdm845-mainline-kernel-builder:ubuntu24.04`
- builder image id: `sha256:5a062f61f63f0d1026de8b5485de5b27535c718ff755c7a911838dc6e8cb3739`

Run a dry check:

```sh
DRY_RUN=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Build the selected mainline branch on the T5:

```sh
CLONE_KERNEL=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

The default target is optimized for G9650 iteration and builds `Image.gz` plus
`qcom/sdm845-samsung-starqltechn.dtb`. Use `BUILD_ALL_DTBS=1` when the full
arm64 DTB set is needed. Use `BUILD_MODULES=1` when a boot-test package also
needs the module tree.

First successful mainline build:

- branch: `6.17-wip/starqltechn_latest_patches`
- head: `f1b20714332646073d4f54190c271917c6da32fa`
- build record: `analysis/mainline-kernel-build-20260704-070427`
- `Image.gz` sha256: `a6afc0b24a1b01f7a239ede43054ecf645404d3c5e795e899f93f0402ce7f8e0`
- `sdm845-samsung-starqltechn.dtb` sha256: `0911308a1ae8b3096875178f8685ea25f7da2d7aed949f5a7fc27ccfd1e09301`

First BCM4361 PCIe Wi-Fi bring-up patch:

- patch: `patches/mainline/0001-g9650-bcm4361-pcie-wifi-bringup.patch`
- record: `docs/mainline-bcm4361-pcie-wifi-bringup-20260704.md`
- build record: `analysis/mainline-kernel-build-20260704-081537`
- `Image.gz` sha256: `db7cfe45366193846796b255e809a96a47658cfacb9c75dd44ee8fea1b92949b`
- `sdm845-samsung-starqltechn.dtb` sha256: `ba302b884313be96831bd2ed51306d187e20137a4f95c3e65b78d9ffb3e85d1b`
- `brcmfmac.ko` sha256: `e99e2cd11f3f5c9c8499afa8a0ce448cc06667efa22c610d5724c48b993b85e4`
