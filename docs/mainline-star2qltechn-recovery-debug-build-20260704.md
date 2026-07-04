# Mainline star2qltechn recovery debug build - 2026-07-04

This records the first mainline recovery debug build that targets the actual
G9650 board identity instead of the older S9 `starqltechn` target.

## Why the previous test likely missed the target

The failed recovery test used `sdm845-samsung-starqltechn.dtb`, whose mainline
identity is:

- model: `Samsung Galaxy S9 SM-G9600`
- compatible: `samsung,starqltechn`, `qcom,sdm845`

The test device is:

- model: `SM-G9650`
- device: `star2qltechn`

The known-good Samsung downstream recovery kernel blob contains STAR2QLTE CHN
DTBs with these bootloader match fields:

- `qcom,msm-id`: `321 65536`, `321 131072`, `321 131073`
- `qcom,board-id`: `8 2` through `8 14`

Because the failed mainline image left no `/sys/fs/pstore` evidence after
returning to Android, the strongest current suspect is earlier than Wi-Fi,
Bluetooth, recovery UI, or userspace. The bootloader may not have selected or
accepted the single appended G9600 `starqltechn` DTB for the G9650 board.

## Source changes

Mainline checkout:

- path: `/Volumes/gts7-android-build/android/kernel-builds/sdm845/mainline-sdm845-linux-next-starqltechn_latest_patches`
- base branch: `6.17-wip/starqltechn_latest_patches`
- local branch: `g9650-bcm4361-bringup`
- base head: `f1b20714332646073d4f54190c271917c6da32fa`

Control repo patch:

- `patches/mainline/0001-g9650-bcm4361-pcie-wifi-bringup.patch`

The patch now contains both bring-up tracks:

- Broadcom BCM4361 PCIe Wi-Fi enumeration work.
- G9650 `star2qltechn` recovery debug targeting.

New recovery-debug DTB:

- `arch/arm64/boot/dts/qcom/sdm845-samsung-star2qltechn.dts`

The new DTS reuses the current `starqltechn` board description, then overrides:

- `model = "Samsung Galaxy S9+ SM-G9650"`
- `compatible = "samsung,star2qltechn", "samsung,starqltechn", "qcom,sdm845"`
- downstream-style `qcom,msm-id`
- downstream-style `qcom,board-id`
- verbose recovery debug bootargs for pstore/ramoops evidence capture

The build wrapper now defaults to:

- output root: `/Volumes/gts7-android-build/android/kernel-builds/sdm845/out-mainline-star2qltechn`
- DTB target: `qcom/sdm845-samsung-star2qltechn.dtb`
- make targets: `Image.gz qcom/sdm845-samsung-star2qltechn.dtb`

## Build

Command:

```sh
RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Build record:

- `analysis/mainline-kernel-build-20260704-113151`

Builder:

- image: `tinnci/sdm845-mainline-kernel-builder:ubuntu24.04`
- image id: `sha256:5a062f61f63f0d1026de8b5485de5b27535c718ff755c7a911838dc6e8cb3739`

Build result:

- exit code: `0`
- `warning/error/fatal` matches in final logs: `0`
- generated DTB count in record: `1`

Artifacts:

| Artifact | Size | SHA256 |
| --- | ---: | --- |
| `arch/arm64/boot/Image.gz` | `15150776` | `806b7c9d2bdae39459e2b2d52af0da33b5e1d2db7f7b12cf54143f4717a2c891` |
| `arch/arm64/boot/Image` | `40614400` | `70df6db4a5e40c463675114cfea262c450d46616ab113f49925cb406b6691eea` |
| `arch/arm64/boot/dts/qcom/sdm845-samsung-star2qltechn.dtb` | `113242` | `98c8a7a2ad4f13b334f716cf66c5596b3d01d44662970f7296f0d3f261242d22` |

## DTB validation

`fdtget` confirmed:

- model: `Samsung Galaxy S9+ SM-G9650`
- compatible: `samsung,star2qltechn samsung,starqltechn qcom,sdm845`
- `qcom,msm-id`: `321 65536 321 131072 321 131073`
- `qcom,board-id`: `8 2 8 3 8 4 8 5 8 6 8 7 8 8 8 9 8 10 8 11 8 12 8 13 8 14`
- ramoops region: `0xa1300000`, size `0x100000`
- ramoops record/console/pmsg sizes: `0x40000` each

Bootargs:

```text
ignore_loglevel loglevel=8 initcall_debug printk.time=1 pstore.backend=ramoops ramoops.mem_address=0xa1300000 ramoops.mem_size=0x100000 ramoops.record_size=0x40000 ramoops.console_size=0x40000 ramoops.pmsg_size=0x40000 panic=10 oops=panic
```

Relevant built config values:

- `CONFIG_BRCMFMAC=m`
- `CONFIG_BRCMFMAC_PCIE=y`
- `CONFIG_SERIAL_EARLYCON=y`
- `CONFIG_USB_DWC3=y`
- `CONFIG_USB_CONFIGFS=y`
- `CONFIG_SCSI_UFS_QCOM=y`
- `CONFIG_PSTORE=y`
- `CONFIG_PSTORE_CONSOLE=y`
- `CONFIG_PSTORE_PMSG=y`
- `CONFIG_PSTORE_RAM=y`
- `CONFIG_PRINTK_TIME=y`
- `CONFIG_MAGIC_SYSRQ=y`

## Next test criteria

The next recovery image should use:

```sh
cat Image.gz sdm845-samsung-star2qltechn.dtb > mainline-Image.gz-dtb
```

Expected result categories:

- If `/sys/fs/pstore` contains mainline 6.17 logs after the test, the bootloader
  entered the kernel and the next work is kernel or recovery userspace bring-up.
- If pstore is still empty, image layout or bootloader DTB selection remains the
  lead suspect. The next iteration should try downstream-style multi-DTB append
  and boot image layout checks before touching drivers.
- If ADB returns in recovery, collect `dmesg`, `/proc/cmdline`, `/proc/device-tree/model`,
  `/sys/firmware/devicetree/base/compatible`, PCI enumeration, and brcmfmac
  firmware requests before making further kernel changes.
