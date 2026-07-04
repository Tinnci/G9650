# Mainline SDM845 Kernel Build Results - 2026-07-04

This records the current successful mainline SDM845 kernel compile path for the
G9650 workspace. The original fast target used `starqltechn`; the current default
uses the G9650 `star2qltechn` debug DTB.

## Build identity

- device target: Samsung Galaxy S9+/SM-G9650 `star2qltechn`
- upstream repo: `https://gitlab.com/dsankouski/sdm845-linux-next.git`
- branch: `6.17-wip/starqltechn_latest_patches`
- head: `f1b20714332646073d4f54190c271917c6da32fa`
- head title: `sdm845.config: enable max98512 downstream codec back because fixed`
- build record: `analysis/mainline-kernel-build-20260704-113151`

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
RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

The first successful run used:

- `defconfig`
- merge `arch/arm64/configs/sdm845.config`
- `olddefconfig`
- targets: `Image.gz qcom/sdm845-samsung-star2qltechn.dtb`

The wrapper now defaults to the faster G9650 path:

```sh
RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Default targets:

- `Image.gz`
- `qcom/sdm845-samsung-star2qltechn.dtb`

Use this when the full DTB set is needed:

```sh
BUILD_ALL_DTBS=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

## Outputs

Output root:

- `/Volumes/gts7-android-build/android/kernel-builds/sdm845/out-mainline-star2qltechn`

Artifacts:

| Artifact | Size | SHA256 |
| --- | ---: | --- |
| `arch/arm64/boot/Image.gz` | `15150776` | `806b7c9d2bdae39459e2b2d52af0da33b5e1d2db7f7b12cf54143f4717a2c891` |
| `arch/arm64/boot/Image` | `40614400` | `70df6db4a5e40c463675114cfea262c450d46616ab113f49925cb406b6691eea` |
| `arch/arm64/boot/dts/qcom/sdm845-samsung-star2qltechn.dtb` | `113242` | `98c8a7a2ad4f13b334f716cf66c5596b3d01d44662970f7296f0d3f261242d22` |

## Log summary

- `build.log`: `35` lines
- `merge-config.log`: `3701` lines
- generated DTB list: `1` file
- warnings: `0`
- errors: `0`
- fatal errors: `0`

No `warning:`, `error:`, or `fatal:` lines were found in the final incremental
build logs.

## Compile signals

The build generated `sdm845-samsung-star2qltechn.dtb` and compiled the expected
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
- `CONFIG_BRCMFMAC=m`
- `CONFIG_BRCMFMAC_PCIE=y`
- `CONFIG_BT_BCM=m`
- `CONFIG_BT_HCIUART=m`
- `CONFIG_BT_HCIUART_BCM=y`
- `CONFIG_PCIE_QCOM=y`

Interpretation:

- The PCIe host controller path exists.
- The Broadcom Bluetooth UART path exists at the generic driver level.
- The current patch enables a first `brcmfmac` PCIe binding attempt for the live
  `14e4:441f` BCM4361 endpoint.
- Firmware/NVRAM packaging is still not solved in this repo.
- Broadcom Bluetooth board modeling is still deferred until the recovery/kernel
  entry problem is understood.

## Next step

Use `docs/mainline-star2qltechn-recovery-debug-build-20260704.md` as the current
boot-test plan. The immediate test is recovery entry evidence, not Wi-Fi success:
pack `Image.gz + sdm845-samsung-star2qltechn.dtb`, boot/flash recovery, then
check whether pstore captures any mainline 6.17 log.
