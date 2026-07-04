# U-Boot starqltechn phone UI build - 2026-07-04

This records the first local build of upstream U-Boot for the Samsung
SDM845 `starqltechn` phone path, packaged in the same broad style used by the
existing postmarketOS image.

## Upstream state

- upstream fork used locally: `https://github.com/Tinnci/u-boot`
- upstream project: `https://github.com/u-boot/u-boot`
- checked-out branch: `master`
- checked-out head: `780084d7c07f511da4a39b43277c573156ed42e0`
- checked-out title: `MAINTAINERS: Add entry for ARM`
- `git describe`: `780084d7`

As of 2026-07-04, upstream U-Boot documents `v2026.04` as the latest released
stable version and schedules `v2026.07` for 2026-07-06. This build intentionally
uses current `master`, not the `v2026.04` stable tag, because the target is
phone bring-up rather than a conservative release baseline.

Relevant upstream references:

- `https://docs.u-boot.org/en/stable/board/qualcomm/board.html`
- `https://docs.u-boot-project.org/en/latest/board/qualcomm/phones.html`
- `https://github.com/u-boot/u-boot/blob/master/doc/develop/release_cycle.rst`

## Source support found

The upstream tree now has the pieces needed for a first S9/S9+ Qualcomm phone
test:

- `configs/qcom_defconfig`
- `board/qualcomm/qcom-phone.config`
- `board/qualcomm/qcom-phone.env`
- `arch/arm/dts/sdm845-samsung-starqltechn-u-boot.dtsi`
- `dts/upstream/src/arm64/qcom/sdm845-samsung-starqltechn.dts`

The older `https://gitlab.com/sdm845-mainline/u-boot` repository is archived and
points users to CodeLinaro `qcomlt/u-boot`. For this test we used the current
official U-Boot tree through the `Tinnci/u-boot` fork.

## Builder

The shared SDM845 builder image now includes the U-Boot build dependencies that
were missing in the first manual attempt:

- `xxd`
- `python3-dev`
- `python3-setuptools`
- `swig`
- `uuid-dev`
- `libgnutls28-dev`

Verified rebuilt image:

- image: `tinnci/sdm845-mainline-kernel-builder:ubuntu24.04`
- image id: `sha256:2aa7b9ebf945fa8a603c37a6cb4fc7897679e94e8f474cdbb87696195daf6cdf`
- image size: `379067975` bytes
- `xxd`: `/usr/bin/xxd`
- `swig`: `/usr/bin/swig`
- aarch64 gcc: `13.3.0`
- clang: `18.1.3`
- python: `3.12.3`
- dtc: `1.7.0`

Rebuild the image and build/package U-Boot with:

```sh
DOCKER_BUILD_IMAGE=1 RUN_DOCKER=1 scripts/uboot/build-starqltechn-phone-u-boot.sh
```

Clone and build from an empty T5 checkout:

```sh
CLONE_UBOOT=1 RUN_DOCKER=1 scripts/uboot/build-starqltechn-phone-u-boot.sh
```

Refresh an existing checkout and rebuild:

```sh
FETCH_UBOOT=1 RUN_DOCKER=1 scripts/uboot/build-starqltechn-phone-u-boot.sh
```

Package only from an existing output directory:

```sh
RUN_DOCKER=0 PACK_ONLY=1 scripts/uboot/build-starqltechn-phone-u-boot.sh
```

## Build configuration

Build record:

- `analysis/u-boot-build-20260704-154853`

Source and output:

- source: `/Volumes/gts7-android-build/android/u-boot-builds/u-boot-master`
- output: `/Volumes/gts7-android-build/android/u-boot-builds/out-u-boot-master-starqltechn-phone-gui`
- config: `qcom_defconfig qcom-phone.config`
- forced default DT: `qcom/sdm845-samsung-starqltechn`
- forced `OF_LIST`: `qcom/sdm845-samsung-starqltechn`
- `SOURCE_DATE_EPOCH`: `1783111370`
- source date UTC: `2026-07-03T20:42:50Z`

Important config checks:

- `CONFIG_DEFAULT_DEVICE_TREE="qcom/sdm845-samsung-starqltechn"`
- `CONFIG_OF_LIST="qcom/sdm845-samsung-starqltechn"`
- `CONFIG_ENV_DEFAULT_ENV_TEXT_FILE="board/qualcomm/qcom-phone.env"`
- `CONFIG_CMD_BOOTMENU=y`
- `CONFIG_BUTTON_REMAP_PHONE_KEYS=y`
- `CONFIG_CONSOLE_RECORD=y`
- `CONFIG_FASTBOOT_CMD_OEM_CONSOLE=y`
- `CONFIG_USB_FUNCTION_ACM=y`
- `CONFIG_VIDEO=y`
- `CONFIG_VIDEO_FONT_16X32=y`
- `CONFIG_VIDEO_LOGO=y`
- `CONFIG_VIDEO_ANSI=y`
- `CONFIG_VIDEO_SIMPLE=y`

This is the upstream phone menu/display path, not a touch UI port.

## U-Boot outputs

| Artifact | SHA-256 |
| --- | --- |
| `u-boot` | `a3739d8e46572f66341945877dd58fdaab7c1c9479bde3cbc9b843affb5159eb` |
| `u-boot.bin` | `943ebb9637325f1eb569fa16491ec89d61733cdfc7e132369b8497bf92eefb9e` |
| `u-boot-nodtb.bin` | `94bfd108b64c69512586a025f31d4298a5137069eda725ab6ae5a51d3b820c14` |
| `u-boot.dtb` | `e2a2afef0613e14575893951c010fd334dbd0a494074567c65df98589c6726c5` |
| `u-boot.map` | `04da33e524b5d377a12c6c668f69feca8f8c71a83ebbee5d87f6d42cef223274` |

## pmOS-style boot image packaging

The existing pmOS boot image template is Android boot header version 0:

- template: `/Users/driezy/Downloads/star2qlte/packages/postmarketos/pmos_extracted/pmos/boot/boot.img`
- kernel load address: `0x00008000`
- ramdisk load address: `0x02000000`
- tags load address: `0x01e00000`
- page size: `4096`

The U-Boot kernel blob was generated as:

```sh
gzip -n -c u-boot-nodtb.bin > u-boot-nodtb.bin.gz
cat u-boot-nodtb.bin.gz u-boot.dtb > u-boot-nodtb.bin.gz-dtb
```

Packaged outputs:

- directory: `analysis/u-boot-build-20260704-154853/packaged`

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `boot-u-boot-starqltechn-phone-gui-nofit.img` | `648K` | `cf736d73ee4827545b8e458d9603c4b810011f1e46fc4e9899a3b38a90a4d28b` |
| `boot-u-boot-starqltechn-phone-gui-pmosfit.img` | `23M` | `d27f0faf1143e17588b7008e7724073d5a39a4f465d2b5b9d34153f10b26cfc2` |
| `boot-u-boot-starqltechn-phone-gui-nofit.tar` | `650K` | `19f62467136e0a00cc7f5af2937321e4f33f29df3bc1920d4dcf300d8dc80ad0` |
| `boot-u-boot-starqltechn-phone-gui-pmosfit.tar` | `23M` | `4a1b81b6c177c5c5fe30ab1fcbd4f359d6d2c8fbb2cb8f8f0a8c2d201d98823d` |

Verification:

- both images unpack as Android boot image header v0
- both use kernel load address `0x00008000`
- both use page size `4096`
- `pmosfit` carries the existing pmOS `boot_image.itb` as ramdisk at
  `0x02000000`

## Interpretation

The reason pmOS can work here is probably not that Samsung ABL accepts a raw
mainline Linux kernel plus one appended DTB better than our recovery tests. The
pmOS-style path is:

1. Samsung ABL loads an Android boot image.
2. The Android boot image's `kernel` payload is U-Boot.
3. U-Boot loads a FIT/ITB payload containing Linux, initramfs, and DTB.

That second-stage handoff is different from the failed direct mainline recovery
tests, where Samsung ABL was asked to enter a mainline `Image.gz + DTB` recovery
kernel directly.

Using one `starqltechn` U-Boot target for S9 and S9+ is plausible for this early
stage because the upstream Qualcomm phone path is shared and the G9600/G9650
Snapdragon variants have enough common early boot hardware. It does not remove
the need for `star2qltechn`-specific Linux/Android details after U-Boot.

## Android and touch support boundary

U-Boot can be useful as a second-stage loader and debug bridge for newer Android
experiments, but it is not a complete Android 16/17 port by itself. Modern
Android still needs compatible `boot`, `vendor_boot`, `init_boot`, `dtbo`,
`vbmeta`/AVB policy, bootconfig/cmdline, vendor ramdisk, dynamic partition
metadata, fstab, SELinux policy, firmware packaging, and vendor HAL behavior.

For touch:

- U-Boot now has a phone display/menu path for this target.
- The practical control path is volume/power buttons and USB console/fastboot.
- U-Boot touchscreen input is not the first bring-up target. It would require
  porting panel, touch controller, regulator, GPIO, and bus initialization into
  U-Boot.
- A Linux or Android kernel launched by U-Boot can still support touch normally
  if the kernel/device tree/userspace stack has the right pieces.

## Next test path

Do not flash this over recovery. This is a boot-partition style experiment.

Recommended order:

1. Back up the current `BOOT` partition from Android root ADB.
2. Flash or boot-test `boot-u-boot-starqltechn-phone-gui-nofit.img` first.
3. If the U-Boot menu appears, test the key path: volume keys, power select,
   USB serial console gadget, and `fastboot oem console`/log behavior.
4. Only after the menu path is proven, test
   `boot-u-boot-starqltechn-phone-gui-pmosfit.img` to validate U-Boot loading
   the existing pmOS FIT payload.
5. Keep Android boot restore ready before attempting any Android-via-U-Boot
   experiment.
