# Mainline SDM845 Kernel Build Results - 2026-07-04

This records the first successful mainline SDM845 kernel compile for the G9650
workspace.

## Build identity

- device target: Samsung Galaxy S9+/SM-G9650 `starqltechn`
- upstream repo: `https://gitlab.com/dsankouski/sdm845-linux-next.git`
- branch: `6.17-wip/starqltechn_latest_patches`
- head: `f1b20714332646073d4f54190c271917c6da32fa`
- head title: `sdm845.config: enable max98512 downstream codec back because fixed`
- build record: `analysis/mainline-kernel-build-20260704-070427`

## Builder

- image: `tinnci/sdm845-mainline-kernel-builder:ubuntu24.04`
- image id: `sha256:5a062f61f63f0d1026de8b5485de5b27535c718ff755c7a911838dc6e8cb3739`
- Dockerfile: `docker/sdm845-mainline-kernel-builder/Dockerfile`

Verified tool versions:

- clang: `Ubuntu clang version 18.1.3 (1ubuntu1)`
- lld: `Ubuntu LLD 18.1.3`
- aarch64 gcc: `13.3.0`
- dtc: `1.7.0`
- pahole: `v1.25`
- make: `GNU Make 4.3`
- python: `3.12.3`

## Command

```sh
CLONE_KERNEL=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

The first successful run used:

- `defconfig`
- merge `arch/arm64/configs/sdm845.config`
- `olddefconfig`
- targets: `Image.gz dtbs`

The wrapper now defaults to the faster G9650 path:

```sh
RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Default targets:

- `Image.gz`
- `qcom/sdm845-samsung-starqltechn.dtb`

Use this when the full DTB set is needed:

```sh
BUILD_ALL_DTBS=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

## Outputs

Output root:

- `/Volumes/gts7-android-build/android/kernel-builds/sdm845/out-mainline-starqltechn`

Artifacts:

| Artifact | Size | SHA256 |
| --- | ---: | --- |
| `arch/arm64/boot/Image.gz` | `15150013` | `a6afc0b24a1b01f7a239ede43054ecf645404d3c5e795e899f93f0402ce7f8e0` |
| `arch/arm64/boot/Image` | `40614400` | `886102905a02f604612cb42fb4d5829fab115f86d5103d3f62465d57d137318a` |
| `arch/arm64/boot/dts/qcom/sdm845-samsung-starqltechn.dtb` | `112014` | `0911308a1ae8b3096875178f8685ea25f7da2d7aed949f5a7fc27ccfd1e09301` |

## Log summary

- `build.log`: `5040` lines
- `merge-config.log`: `3701` lines
- generated DTB list: `351` files
- warnings: `6`
- errors: `0`
- fatal errors: `0`

Warnings were limited to unused variables in panel drivers:

- `drivers/gpu/drm/panel/panel-lg-sw43408.c`
- `drivers/gpu/drm/panel/panel-samsung-s6e3ha8.c`

## Compile signals

The build generated `sdm845-samsung-starqltechn.dtb` and compiled the expected
support areas for a first mainline bring-up pass:

- Qualcomm PCIe host: `CONFIG_PCIE_QCOM=y`
- Qualcomm GENI serial: `CONFIG_SERIAL_QCOM_GENI=y`
- Qualcomm GENI I2C: `CONFIG_I2C_QCOM_GENI=y`
- Qualcomm WLED backlight: `CONFIG_BACKLIGHT_QCOM_WLED=y`
- Samsung S6E3HA8 panel: `CONFIG_DRM_PANEL_SAMSUNG_S6E3HA8=y`
- Qualcomm SMMU: `CONFIG_ARM_SMMU_QCOM=y`
- Qualcomm SDM845 interconnect: `CONFIG_INTERCONNECT_QCOM_SDM845=y`
- Samsung support pieces including `sec-common`, `sec-irq`, and `sec-i2c`

## Wireless status

The build is not yet a wireless fix.

Observed config:

- `CONFIG_WLAN_VENDOR_BROADCOM=y`
- `CONFIG_BRCMFMAC` is not set
- `CONFIG_BT_BCM=m`
- `CONFIG_BT_HCIUART=m`
- `CONFIG_BT_HCIUART_BCM=y`
- `CONFIG_PCIE_QCOM=y`

Interpretation:

- The PCIe host controller path exists.
- The Broadcom Bluetooth UART path exists at the generic driver level.
- The Broadcom BCM4361 Wi-Fi path is still missing because no usable Broadcom
  Wi-Fi driver is enabled for this device.
- The device tree still needs the narrow Samsung downstream comparison for
  WLAN enable, host-wake, PCIe RC0 expectations, BT reset/wake/bluesleep GPIOs,
  and firmware packaging.

## Next step

Use this successful compile as the baseline for a narrow wireless port:

- compare mainline `arch/arm64/boot/dts/qcom/sdm845-samsung-starqltechn.dts`
  with Samsung downstream `sdm845-sec-star2qlte-chn-r04.dts`
- add only the board-level Wi-Fi/BT nodes and GPIOs that are defensible from
  downstream and live-device evidence
- keep build validation on the fast default target
- only move to boot testing after the DTB delta is small, reviewable, and
  traceable to downstream or live hardware evidence
