# G9650 mainline recovery bring-up test

Date: 2026-07-04

Target device:

- Model: `SM-G9650`
- Device: `star2qltechn`
- ADB serial used for the test: `21a997b801037ece`

## Inputs

Known-good recovery baseline:

- Source image: `/Users/driezy/Downloads/star2qlte/repos/Tinnci-star2qlte-maintenance/analysis/twrp-build-20260703-055506/recovery.img`
- Source image SHA-256: `26853acce3e73081d596bf0252d881120f7d7bb1a86f574921ea8a051766909c`

Mainline kernel build outputs:

- `Image.gz`: `/Volumes/gts7-android-build/android/kernel-builds/sdm845/out-mainline-starqltechn/arch/arm64/boot/Image.gz`
- `Image.gz` SHA-256: `db7cfe45366193846796b255e809a96a47658cfacb9c75dd44ee8fea1b92949b`
- DTB: `/Volumes/gts7-android-build/android/kernel-builds/sdm845/out-mainline-starqltechn/arch/arm64/boot/dts/qcom/sdm845-samsung-starqltechn.dtb`
- DTB SHA-256: `ba302b884313be96831bd2ed51306d187e20137a4f95c3e65b78d9ffb3e85d1b`

## Packing result

The known-good recovery image is Android boot image header version 0:

- Page size: `4096`
- Kernel load address: `0x00008000`
- Ramdisk load address: `0x02000000`
- Tags load address: `0x01e00000`
- Ramdisk size: `22325532`
- Samsung tail marker: `SEANDROIDENFORCE`

Round-trip repacking with AOSP `mkbootimg.py` is byte-identical to the source image after appending the Samsung `SEANDROIDENFORCE` tail marker. This validates the local pack path.

The mainline test kernel blob was built as:

```sh
cat Image.gz sdm845-samsung-starqltechn.dtb > mainline-Image.gz-dtb
```

Generated artifacts:

- Work dir: `analysis/mainline-recovery-bringup-20260704-172126`
- Kernel blob SHA-256: `c9e0a054b44bc7123fbbb68ba12d1c68b3aabe13adc944b7355f1b82c05d7ee2`
- Recovery image: `analysis/mainline-recovery-bringup-20260704-172126/out/recovery-mainline-bringup.img`
- Recovery image SHA-256: `9c24232326a4d906ce1266763908fb655e073cdcf30fb9c68684d8f7e46510bf`
- Odin-style tar: `analysis/mainline-recovery-bringup-20260704-172126/out/recovery-mainline-bringup.tar`
- Tar SHA-256: `b476ddb4bd1f630ff5fc4298de3fae730435075065bff9e9d0c7d7cf50379bfb`

Strict artifact verification passed for both `.img` and `.tar`:

- Fits recovery partition size `72339456`
- Has `SEANDROIDENFORCE`
- Header version `0`
- Page size `4096`
- Ramdisk offset `0x02000000`
- Cmdline includes `androidboot.hardware=qcom`, `androidboot.configfs=true`, and `androidboot.usbcontroller=a600000.dwc3`

## Device flash result

Flash record:

- `analysis/mainline-recovery-bringup-20260704-172126/flash-20260704-172549-21a997b801037ece`

Before flashing, the current recovery partition was backed up:

- Backup: `recovery-preflash.img`
- Backup size: `72339456`
- Backup SHA-256: `affbb7036211e5c1c802133e8f212468465007a58378d4ed9176767ebae882f8`

The mainline recovery image was pushed to the device and its remote SHA-256 matched the local image:

- Remote image SHA-256: `9c24232326a4d906ce1266763908fb655e073cdcf30fb9c68684d8f7e46510bf`

The image was written to `/dev/block/sda21`, then the recovery partition prefix was read back. The prefix SHA-256 matched the image:

- Recovery prefix SHA-256: `9c24232326a4d906ce1266763908fb655e073cdcf30fb9c68684d8f7e46510bf`

After `adb reboot recovery`, the device did not return through ADB within 180 seconds. macOS USB inspection also did not show the G9650 as an Android/Samsung phone. Only the unrelated Samsung T5 storage device was visible.

## Conclusion

This mainline recovery test image is correctly packed and was correctly written to the recovery partition, but it does not currently boot far enough to enumerate USB or start recovery ADB.

Treat this as a kernel or early boot compatibility failure, not a packing failure.

Most likely next suspects:

- Bootloader does not accept a single raw mainline DTB appended after `Image.gz`, despite the downstream blob containing appended raw DTBs.
- The mainline DTB is missing boot-critical Samsung downstream nodes or reserved-memory details needed before userspace.
- The recovery ramdisk expects downstream Android kernel behavior that the current mainline kernel does not provide.
- Display, USB gadget, storage, or init dependencies are built as modules or otherwise unavailable before recovery userspace starts.

## Recovery path

If the phone is stuck in this recovery boot, force reboot to Android without holding the recovery key combo. After Android ADB returns, restore the preflash recovery image to `/dev/block/sda21`.

If Android does not boot, enter Download Mode and flash a known-good recovery tar from the previous validated TWRP/PBRP build.

## Recovery and log search follow-up

The phone entered Download Mode after the failed mainline recovery boot. Non-root Heimdall could detect `Samsung SDM845` but failed Odin/Loke bulk handshakes. Running Grimler Heimdall v2.2.2 with `sudo` succeeded for `close-pc-screen`, and the device rebooted into Android/System.

The recovery partition was restored from the preflash backup:

- Backup SHA-256: `affbb7036211e5c1c802133e8f212468465007a58378d4ed9176767ebae882f8`
- Restored block: `/dev/block/sda21`
- Read-back SHA-256 after restore: `affbb7036211e5c1c802133e8f212468465007a58378d4ed9176767ebae882f8`

Failed-recovery log search record:

- `analysis/mainline-recovery-bringup-20260704-172126/failed-recovery-log-search-20260704-180217`

Findings:

- `/sys/fs/pstore` exists but was empty after returning to Android.
- `/proc/last_kmsg` was captured, but it identifies the current Android/System boot, not the failed mainline recovery boot:
  - bootloader selected `Kernel binary: boot`
  - `TZ informed of recovery status: 0`
  - kernel version `4.9.337-Rel10`
  - command line has `root=/dev/sda22`
  - command line has `androidboot.boot_recovery=0`
  - no `6.17`, `mainline`, or `sdm845-linux-next` evidence was found
- `/cache/recovery/last_log.gz` was an older successful PBRP/TWRP log, not this failed mainline recovery attempt.
- `misc` first 64 KiB did not contain `boot-recovery`; only `roms` was visible through `strings`.

Conclusion: no direct mainline recovery kernel log survived this test. The next test image should deliberately improve early evidence capture before another recovery flash attempt.

Kernel dump notes:

- Kernel dumps are useful here, but only after the test kernel reaches the pstore/ramoops driver or a platform-specific crash dumper.
- The current mainline DTS already reserves a Samsung-style ramoops region at `0xa1300000` with size `0x100000`.
- The built mainline config already has `CONFIG_PSTORE=y`, `CONFIG_PSTORE_CONSOLE=y`, `CONFIG_PSTORE_PMSG=y`, and `CONFIG_PSTORE_RAM=y`.
- The failed test still left `/sys/fs/pstore` empty after Android returned, which means either:
  - the mainline kernel did not reach pstore/ramoops registration,
  - it hung without panic/oops before useful console text was persisted,
  - the bootloader never successfully transferred into the mainline kernel, or
  - the subsequent Android boot cleared or did not expose that previous pstore content.

Next kernel-dump-focused build variant:

- Increase retained pstore console/kmsg budget where possible.
- Add bootargs such as `ignore_loglevel`, `loglevel=8`, `initcall_debug`, and `printk.time=1`.
- Prefer a debug-only build with stronger panic behavior for oops/warn/lockup, so hangs become recoverable crash dumps instead of silent stalls.
- Verify the DT `ramoops` node matches the downstream Android kernel reservation observed at boot:
  - downstream pstore attaches `0x100000@0xa1300000`
  - current mainline DTS uses `memory@a1300000`
- If pstore still remains empty, test whether the bootloader accepted the mainline kernel at all by changing the image composition before touching drivers: downstream-style multi-DTB append, DTBO handling, and original kernel blob layout.

## Next debug step

The next useful iteration is not another blind recovery repack. Build a boot-test variant that maximizes early evidence:

- Add a bootarg set for verbose early logging where useful.
- Preserve or reproduce downstream appended-DTB layout more closely.
- Check whether pstore/ramoops captures anything after the failed recovery attempt.
- Consider building boot-critical display, USB, storage, and input drivers built-in rather than as modules for this recovery bring-up image.

## star2qltechn debug rebuild

This next debug build has now been prepared and compiled:

- build record: `analysis/mainline-kernel-build-20260704-113151`
- output root: `/Volumes/gts7-android-build/android/kernel-builds/sdm845/out-mainline-star2qltechn`
- kernel: `arch/arm64/boot/Image.gz`
- DTB: `arch/arm64/boot/dts/qcom/sdm845-samsung-star2qltechn.dtb`
- DTB SHA-256: `98c8a7a2ad4f13b334f716cf66c5596b3d01d44662970f7296f0d3f261242d22`

Important correction:

- The failed recovery test used `sdm845-samsung-starqltechn.dtb`, which is the
  S9/G9600 mainline target.
- The actual device is S9+/G9650 `star2qltechn`.
- The new debug DTB advertises `Samsung Galaxy S9+ SM-G9650`,
  `samsung,star2qltechn`, and the downstream STAR2QLTE CHN `qcom,msm-id` /
  `qcom,board-id` values seen in the known-good recovery kernel blob.

Current assessment:

- The reason mainline did not reach the target is probably earlier than Wi-Fi,
  Bluetooth, recovery UI, or Android userspace.
- Because pstore was empty after the failed test, we do not yet have proof that
  the bootloader entered the mainline kernel.
- The next test should use the new `star2qltechn` DTB. If pstore is still empty,
  the next suspect is image layout or bootloader DTB selection, especially
  downstream-style multi-DTB append behavior.
