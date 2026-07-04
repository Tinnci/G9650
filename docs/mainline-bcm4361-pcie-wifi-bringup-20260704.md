# Mainline BCM4361 PCIe Wi-Fi and star2qltechn Bring-Up - 2026-07-04

This records the first narrow mainline bring-up patch for the G9650 Broadcom
BCM4361 Wi-Fi path. The same patch now also carries the G9650 `star2qltechn`
debug DTB needed before another recovery boot test.

## Scope

Goal:

- keep the existing PBRP/downstream investigation separate from this mainline
  test path
- use the selected dsankouski 6.17 WIP mainline branch as the base
- add the smallest traceable Wi-Fi/PCIe delta needed for the device to enumerate
  the Broadcom BCM4361 endpoint and bind `brcmfmac`
- add a G9650 `star2qltechn` DTB target so recovery tests do not keep using the
  S9/G9600 `starqltechn` identity
- improve early recovery evidence capture with pstore/ramoops-oriented bootargs
- defer Broadcom Bluetooth board modeling until Wi-Fi PCIe enumeration has boot
  evidence

Non-goals for this patch:

- no downstream `android,bcmdhd_wlan` node copied into mainline
- no downstream `bcm,btdriver` or `bcm,bluesleep` nodes copied into mainline
- no firmware/NVRAM blobs stored in this repo
- no repartitioning, AVB, bootloader, or Android userspace changes

## Source State

Mainline checkout:

- path: `/Volumes/gts7-android-build/android/kernel-builds/sdm845/mainline-sdm845-linux-next-starqltechn_latest_patches`
- branch: `g9650-bcm4361-bringup`
- base branch: `6.17-wip/starqltechn_latest_patches`
- local last-known selected head: `f1b20714332646073d4f54190c271917c6da32fa`
- head title: `sdm845.config: enable max98512 downstream codec back because fixed`

Remote note:

- `git fetch` and `git ls-remote` against GitLab failed on 2026-07-04 with
  `LibreSSL SSL_connect: SSL_ERROR_SYSCALL`.
- Because of that, this result is based on the local last-known selected head,
  not a freshly confirmed remote head.

Patch stored in this control repo:

- `patches/mainline/0001-g9650-bcm4361-pcie-wifi-bringup.patch`

The patch now includes the recovery debug DTB update documented in:

- `docs/mainline-star2qltechn-recovery-debug-build-20260704.md`

## Evidence Used

Live device evidence from the working Android boot:

- model: `SM-G9650`
- device: `star2qltechn`
- Wi-Fi PCI endpoint: vendor `0x14e4`, device `0x441f`, subdevice `0x4361`
- PCI root complex path: `1c00000.qcom,pcie`
- Bluetooth firmware prop: `BCM4361B2 Crown 1QW ANT1 [Version: 0110.0230]`
- Bluetooth tty prop: `ttyHS0`

Samsung downstream DTS evidence:

- Wi-Fi uses PCIe RC0, not SDIO.
- PCIe pins:
  - PERST: TLMM GPIO35
  - CLKREQ: TLMM GPIO36
  - wake: TLMM GPIO37
- WLAN GPIOs:
  - WLAN enable: TLMM GPIO99
  - WLAN host wake: TLMM GPIO116
- Broadcom Bluetooth downstream GPIOs:
  - BT reset: PM8998 GPIO3
  - BT wake: TLMM GPIO136
  - BT host wake: TLMM GPIO108

## Patch Summary

The patch changes 7 files:

- `arch/arm64/boot/dts/qcom/Makefile`
- `arch/arm64/boot/dts/qcom/sdm845-samsung-star2qltechn.dts`
- `arch/arm64/boot/dts/qcom/sdm845-samsung-starqltechn.dts`
- `arch/arm64/configs/sdm845.config`
- `drivers/net/wireless/broadcom/brcm80211/include/brcm_hw_ids.h`
- `drivers/net/wireless/broadcom/brcm80211/brcmfmac/pcie.c`
- `drivers/net/wireless/broadcom/brcm80211/brcmfmac/chip.c`

DTS changes:

- add `wlan-en-regulator` on TLMM GPIO99
- enable `&pcie0`
- enable `&pcie0_phy`
- add PCIe RC0 pinctrl for GPIO35/GPIO36/GPIO37
- use `vddpe-3v3-supply = <&wlan_en>` as the first mainline-safe WLAN enable
  hook

Config changes:

- `CONFIG_PRINTK_TIME=y`
- `CONFIG_MAGIC_SYSRQ=y`
- `CONFIG_SERIAL_EARLYCON=y`
- `CONFIG_BRCMFMAC=m`
- `CONFIG_BRCMFMAC_PCIE=y`

brcmfmac changes:

- add chip id `BRCM_CC_4361_CHIP_ID`
- add PCI id `BRCM_PCIE_4361_DEVICE_ID` for live endpoint `14e4:441f`
- add firmware mapping `brcmfmac4361-pcie`
- group BCM4361 with the BCM4359 TCM rambase/save-restore handling as a first
  boot-test assumption

## Current Image/DTB Build Result

Latest fast recovery-debug build record:

- `analysis/mainline-kernel-build-20260704-113151`

Fast image/DTB command:

```sh
RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Outputs:

| Artifact | SHA256 |
| --- | --- |
| `arch/arm64/boot/Image.gz` | `806b7c9d2bdae39459e2b2d52af0da33b5e1d2db7f7b12cf54143f4717a2c891` |
| `arch/arm64/boot/Image` | `70df6db4a5e40c463675114cfea262c450d46616ab113f49925cb406b6691eea` |
| `arch/arm64/boot/dts/qcom/sdm845-samsung-star2qltechn.dtb` | `98c8a7a2ad4f13b334f716cf66c5596b3d01d44662970f7296f0d3f261242d22` |

The final incremental build log had no `warning:`, `error:`, or `fatal:` lines.

## Earlier Module Build Result

Build record:

- `analysis/mainline-kernel-build-20260704-081537`

Fast image/DTB command:

```sh
FETCH_KERNEL=0 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Full modules command used before the wrapper gained `BUILD_MODULES=1`:

```sh
docker run --rm \
  -v /Volumes/gts7-android-build:/work/t5 \
  -v /Users/driezy/Downloads/G9650:/workspace/g9650 \
  tinnci/sdm845-mainline-kernel-builder:ubuntu24.04 \
  bash -lc 'set -euo pipefail
cd /work/t5/android/kernel-builds/sdm845/mainline-sdm845-linux-next-starqltechn_latest_patches
make O=/work/t5/android/kernel-builds/sdm845/out-mainline-starqltechn ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- -j8 modules 2>&1 | tee /workspace/g9650/analysis/mainline-kernel-build-20260704-081537/modules-build.log
'
```

Equivalent wrapper command for future runs:

```sh
BUILD_MODULES=1 RUN_DOCKER=1 scripts/kernel/build-mainline-sdm845-kernel.sh
```

Outputs:

| Artifact | SHA256 |
| --- | --- |
| `arch/arm64/boot/Image.gz` | `db7cfe45366193846796b255e809a96a47658cfacb9c75dd44ee8fea1b92949b` |
| `arch/arm64/boot/Image` | `2d0142ba0dfb91c22b50a49dc59900cb6895e368e9597383c372d8c5b9e7c29e` |
| `arch/arm64/boot/dts/qcom/sdm845-samsung-starqltechn.dtb` | `ba302b884313be96831bd2ed51306d187e20137a4f95c3e65b78d9ffb3e85d1b` |
| `drivers/net/wireless/broadcom/brcm80211/brcmfmac/brcmfmac.ko` | `e99e2cd11f3f5c9c8499afa8a0ce448cc06667efa22c610d5724c48b993b85e4` |
| `drivers/net/wireless/broadcom/brcm80211/brcmutil/brcmutil.ko` | `208357853f5b80afdf52f6cd46bc782335ff6bd9e48d346b8369d8aa378ec2db` |
| `net/wireless/cfg80211.ko` | `b0ad8489e1d1d403305ab2b2107848d27023c9abd78f24c2e7daf5375fc3daf1` |
| `net/mac80211/mac80211.ko` | `c7f6ab9e96b82fa22baab651fd6b0b8f8976f859fc80e4590af38e34c56a8c32` |
| `net/rfkill/rfkill.ko` | `e52fe941394a49efea350bc5038bbea2ef69d500751feee5faf84f6ee033b0b9` |
| `drivers/bluetooth/hci_uart.ko` | `1fa271926bc9b541f33f4337858827f6dfed4dca116aec75d2136a59e100ec35` |
| `drivers/bluetooth/btbcm.ko` | `48f74567303f07ddd4276acebcfb84f9814d3bce2203f02c0d5b5a7baa6695fd` |

Module count:

- `973` `.ko` files under `out-mainline-starqltechn`

Config evidence from the built `.config`:

- `CONFIG_PCIE_QCOM=y`
- `CONFIG_BRCMFMAC=m`
- `CONFIG_BRCMFMAC_PCIE=y`
- `CONFIG_CFG80211=m`
- `CONFIG_MAC80211=m`
- `CONFIG_RFKILL=m`
- `CONFIG_BT_BCM=m`
- `CONFIG_BT_HCIUART=m`
- `CONFIG_BT_HCIUART_BCM=y`
- `CONFIG_SERIAL_DEV_BUS=y`

Log notes:

- `build.log`: fast `Image.gz` plus G9650 DTB completed successfully.
- `modules-build.log`: full modules completed successfully.
- `brcmfmac-module-build.log`: targeted `M=.../brcmfmac modules` compiled the
  changed objects but failed at `MODPOST` because the fast image-only build had
  not generated global `Module.symvers`; the full `make modules` run superseded
  this and produced `brcmfmac.ko`.
- `modules-build.log` contains warning lines in existing downstream audio,
  touchscreen, and media code; no hard errors were observed in the successful
  full modules run.

## Boot-Test Expectations

The next recovery boot test should first answer whether the bootloader enters
the mainline kernel with the new `star2qltechn` DTB. If it does, the Wi-Fi test
should answer these questions in order:

1. Does `&pcie0` link train?
2. Does Linux enumerate the Broadcom endpoint as `14e4:441f`?
3. Does `brcmfmac` bind to the endpoint?
4. Does `brcmfmac` request `brcm/brcmfmac4361-pcie*.bin` and a matching NVRAM
   text file?
5. Does the BCM4359-family TCM rambase assumption work for BCM4361B2?

Expected first failure is likely firmware/NVRAM packaging, not compilation.
Samsung downstream uses:

- firmware path: `/etc/wifi/bcmdhd_sta.bin`
- NVRAM path: `/etc/wifi/nvram_net.txt`

Mainline `brcmfmac` will request names under `brcm/`, likely including
`brcmfmac4361-pcie.bin` or a board-specific variant. Any firmware/NVRAM test
copy should be treated as device-local testing material unless redistribution
rights are clear.

## Follow-Up

Next practical steps:

- boot the patched `Image.gz` plus `sdm845-samsung-star2qltechn.dtb`
- collect `dmesg` with `pcie`, `brcmfmac`, `firmware`, `cfg80211`, `rfkill`, and
  `bluetooth` filters
- if pstore is empty again, stop driver work and test downstream-style multi-DTB
  append or boot image layout first
- if PCIe does not enumerate, revisit GPIO99 WLAN enable and PCIe RC0 regulator
  sequencing
- if PCIe enumerates but firmware fails, prepare a local firmware/NVRAM mapping
  test package
- only after Wi-Fi enumeration is understood, add mainline-style Broadcom BT
  UART child modeling for PM8998 GPIO3 reset plus wake/host-wake GPIOs
