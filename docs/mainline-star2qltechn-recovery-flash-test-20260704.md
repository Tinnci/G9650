# Mainline star2qltechn recovery flash test - 2026-07-04

This records the first recovery flash test using the corrected G9650
`star2qltechn` mainline DTB.

## Artifact

Build input:

- kernel: `/Volumes/gts7-android-build/android/kernel-builds/sdm845/out-mainline-star2qltechn/arch/arm64/boot/Image.gz`
- kernel SHA-256: `806b7c9d2bdae39459e2b2d52af0da33b5e1d2db7f7b12cf54143f4717a2c891`
- DTB: `/Volumes/gts7-android-build/android/kernel-builds/sdm845/out-mainline-star2qltechn/arch/arm64/boot/dts/qcom/sdm845-samsung-star2qltechn.dtb`
- DTB SHA-256: `98c8a7a2ad4f13b334f716cf66c5596b3d01d44662970f7296f0d3f261242d22`

Packaging record:

- `analysis/mainline-recovery-bringup-star2qltechn-20260704-115626`

Generated files:

- kernel blob: `work/mainline-star2qltechn-Image.gz-dtb`
- recovery image: `out/recovery-mainline-star2qltechn.img`
- Odin-style tar: `out/recovery-mainline-star2qltechn.tar`

SHA-256:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `mainline-star2qltechn-Image.gz-dtb` | `15264018` | `3211204a2a5ee78c11029b59e5b46a3a848d0332ccd68f02c0aa3a04c2435fbb` |
| `recovery-mainline-star2qltechn.img` | `37597200` | `de673c8976fce524e237bc546feb3e5d6aad255457f7a5dbf5f3c198f48fa4f9` |
| `recovery-mainline-star2qltechn.tar` | `37599232` | `a5926126031b9ef3bfe00d05d978faa4573d38ddb14decb8a14a59214721b411` |

Verification passed for both `.img` and `.tar`:

- fits recovery partition size `72339456`
- has `SEANDROIDENFORCE`
- boot image header version `0`
- page size `4096`
- ramdisk offset `0x02000000`
- cmdline contains `androidboot.hardware=qcom`
- cmdline contains `androidboot.configfs=true`
- cmdline contains `androidboot.usbcontroller=a600000.dwc3`
- tar contains `recovery.img` at archive root

## Flash

Device:

- serial: `21a997b801037ece`
- model: `SM-G9650`
- device: `star2qltechn`
- bootloader: `G9650ZCS9FVA4`

Flash record:

- `analysis/mainline-recovery-bringup-star2qltechn-20260704-115626/flash-20260704-115832-21a997b801037ece-root`

Method:

- Android ADB with root `su`
- recovery block: `/dev/block/sda21`
- backup first, then write new image, then read back prefix SHA

Preflash recovery backup:

- path: `recovery-preflash.img`
- size: `72339456`
- SHA-256: `affbb7036211e5c1c802133e8f212468465007a58378d4ed9176767ebae882f8`

Written recovery prefix SHA matched the new image:

- expected: `de673c8976fce524e237bc546feb3e5d6aad255457f7a5dbf5f3c198f48fa4f9`
- read-back prefix: `de673c8976fce524e237bc546feb3e5d6aad255457f7a5dbf5f3c198f48fa4f9`

## Boot result

After `adb reboot recovery`, ADB did not return while polling for recovery.
The wait log reached at least `210` seconds with the device absent from ADB.

The phone then entered Download Mode. macOS USB identified it as:

- product: `SDM845`
- vendor: `0x04e8`
- product ID: `0x685d`

This is still a failed mainline recovery boot. The corrected `star2qltechn` DTB
did not bring the image far enough for recovery ADB.

## Heimdall recovery path

The local Heimdall override was used for this test path:

```sh
PATH=/Users/driezy/Downloads/G9650/analysis/tools/Heimdall-grimler-v2.2.2/build/bin:$PATH
```

Heimdall identity:

- binary: `analysis/tools/Heimdall-grimler-v2.2.2/build/bin/heimdall`
- version: `v2.2.2`

Heimdall results:

- `heimdall detect` succeeded in Download Mode.
- `heimdall print-pit --no-reboot` succeeded.
- PIT confirmed recovery partition name `RECOVERY`, identifier `21`.
- `heimdall flash --RECOVERY recovery-preflash.img --no-reboot` failed during
  protocol initialization.
- retrying with `--resume --no-reboot` began a session, then USB disconnected
  and the phone returned to Android/System.

`sudo` was not needed after the phone returned to Android, because root ADB was
available and safer for restoring the exact preflash recovery backup.

## Restore

Restore record:

- `analysis/mainline-recovery-bringup-star2qltechn-20260704-115626/adb-root-restore-preflash-20260704-120530`

Method:

- pushed the preflash recovery backup to `/data/local/tmp`
- wrote it back with `su -c dd`
- read back the full recovery partition

Final recovery partition SHA-256:

- `affbb7036211e5c1c802133e8f212468465007a58378d4ed9176767ebae882f8`

The known-good recovery partition was restored.

## Log evidence

Post-failure log record:

- `analysis/mainline-recovery-bringup-star2qltechn-20260704-115626/post-failed-star2-recovery-log-search-20260704-120507`

Findings:

- `/sys/fs/pstore` existed but was empty.
- No pstore console, dmesg, pmsg, or ramoops file survived the failed recovery
  boot attempt.
- `/proc/last_kmsg` described the subsequent Android/System boot, not a
  mainline recovery boot.
- `/proc/last_kmsg` contained `Kernel binary: boot`.
- `/proc/last_kmsg` contained `TZ informed of recovery status: 0`.
- `/proc/last_kmsg` contained `androidboot.boot_recovery=0`.
- No `6.17`, `sdm845-linux-next`, or direct mainline kernel evidence was found.

Interpretation:

- The corrected G9650 `star2qltechn` DTB was necessary, but not sufficient.
- We still do not have proof that the bootloader entered the mainline kernel.
- This remains earlier than Wi-Fi, Bluetooth, or recovery UI.

## Kexec handoff check

Jumping from the running Android system or recovery into the mainline kernel
would require kexec support in the currently running kernel. The current Android
system kernel does not have it:

- running kernel: `Linux localhost 4.9.337-Rel10`
- `/proc/config.gz`: `# CONFIG_KEXEC is not set`
- Samsung downstream `star2qlte_chn_open_defconfig`: `# CONFIG_KEXEC is not set`
- built downstream output `.config`: `# CONFIG_KEXEC is not set`

That means the current Android system cannot directly `kexec` into the mainline
kernel for temporary log capture.

A dedicated kexec-enabled downstream recovery kernel could be built later, but
it would answer a different question: whether Linux can chain-load the mainline
kernel after Samsung's downstream kernel has already booted. It would not prove
that Samsung's bootloader accepts the mainline recovery image or its appended
DTB layout.

## Next step

Do not spend the next iteration on BCM4361 or recovery userspace yet. The next
target should be boot image layout and DTB delivery:

- compare the known-good downstream recovery kernel blob's appended multi-DTB
  layout against the mainline `Image.gz + single DTB` layout
- try downstream-style multi-DTB append for STAR2QLTE CHN board revisions
- verify whether the bootloader requires Samsung/QCDT-style DTB metadata rather
  than a plain appended FDT
- only resume driver bring-up after pstore or another channel proves the
  mainline kernel starts executing
