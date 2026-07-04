#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DOCKER_IMAGE="${DOCKER_IMAGE:-gts7-android-recovery-build:22.04}"
DOCKER_BUILD_ROOT="${DOCKER_BUILD_ROOT:-/Volumes/gts7-android-build}"
HOST_ANDROID_DIR="${HOST_ANDROID_DIR:-$DOCKER_BUILD_ROOT/android}"
CONTAINER_ANDROID_DIR="${CONTAINER_ANDROID_DIR:-/android/android}"

KERNEL_REPO="${KERNEL_REPO:-https://github.com/klabit87/android_kernel_samsung_sdm845.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:-q}"
KERNEL_NAME="${KERNEL_NAME:-klabit87-android_kernel_samsung_sdm845-q}"
HOST_KERNEL_ROOT="${HOST_KERNEL_ROOT:-$DOCKER_BUILD_ROOT/kernel-sdm845}"
HOST_KERNEL_SRC="${HOST_KERNEL_SRC:-$HOST_KERNEL_ROOT/$KERNEL_NAME}"
HOST_KERNEL_OUT="${HOST_KERNEL_OUT:-$HOST_KERNEL_ROOT/out/star2qlte_chn_open}"
CONTAINER_KERNEL_SRC="${CONTAINER_KERNEL_SRC:-/android/kernel-sdm845/$KERNEL_NAME}"
CONTAINER_KERNEL_OUT="${CONTAINER_KERNEL_OUT:-/android/kernel-sdm845/out/star2qlte_chn_open}"

DEFCONFIG="${DEFCONFIG:-star2qlte_chn_open_defconfig}"
TARGETS="${TARGETS:-Image.gz-dtb dtbs}"
JOBS="${JOBS:-4}"
USE_CLANG="${USE_CLANG:-0}"
KCFLAGS="${KCFLAGS:--mno-android}"
RUN_DOCKER="${RUN_DOCKER:-0}"
DRY_RUN="${DRY_RUN:-0}"
CLONE_KERNEL="${CLONE_KERNEL:-0}"
STAMP="${STAMP:-$(date -u '+%Y%m%d-%H%M%S')}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/analysis/kernel-build-$STAMP}"

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$1" >&2
        exit 1
    fi
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1"
    else
        shasum -a 256 "$1"
    fi
}

print_config() {
    printf 'root_dir=%s\n' "$ROOT_DIR"
    printf 'docker_image=%s\n' "$DOCKER_IMAGE"
    printf 'docker_build_root=%s\n' "$DOCKER_BUILD_ROOT"
    printf 'host_android_dir=%s\n' "$HOST_ANDROID_DIR"
    printf 'container_android_dir=%s\n' "$CONTAINER_ANDROID_DIR"
    printf 'kernel_repo=%s\n' "$KERNEL_REPO"
    printf 'kernel_branch=%s\n' "$KERNEL_BRANCH"
    printf 'host_kernel_src=%s\n' "$HOST_KERNEL_SRC"
    printf 'host_kernel_out=%s\n' "$HOST_KERNEL_OUT"
    printf 'container_kernel_src=%s\n' "$CONTAINER_KERNEL_SRC"
    printf 'container_kernel_out=%s\n' "$CONTAINER_KERNEL_OUT"
    printf 'defconfig=%s\n' "$DEFCONFIG"
    printf 'targets=%s\n' "$TARGETS"
    printf 'jobs=%s\n' "$JOBS"
    printf 'use_clang=%s\n' "$USE_CLANG"
    printf 'kcflags=%s\n' "$KCFLAGS"
    printf 'dry_run=%s\n' "$DRY_RUN"
    printf 'run_docker=%s\n' "$RUN_DOCKER"
    printf 'clone_kernel=%s\n' "$CLONE_KERNEL"
    printf 'log_dir=%s\n' "$LOG_DIR"
}

if [ "$DRY_RUN" = "1" ]; then
    print_config
    cat <<EOF

Dry run complete. To clone the kernel source onto the T5 and run the Docker build:

  CLONE_KERNEL=1 RUN_DOCKER=1 $0

If the source already exists at $HOST_KERNEL_SRC:

  RUN_DOCKER=1 $0

Equivalent Docker command:

  docker run --rm \\
    -v "$DOCKER_BUILD_ROOT:/android" \\
    -v "$ROOT_DIR:/star2" \\
    "$DOCKER_IMAGE" \\
    bash -lc 'set -euo pipefail; cd /star2; CONTAINER_ANDROID_DIR=$CONTAINER_ANDROID_DIR CONTAINER_KERNEL_SRC=$CONTAINER_KERNEL_SRC CONTAINER_KERNEL_OUT=$CONTAINER_KERNEL_OUT DEFCONFIG=$DEFCONFIG TARGETS="$TARGETS" JOBS=$JOBS USE_CLANG=$USE_CLANG KCFLAGS="$KCFLAGS" ./scripts/kernel/build-sdm845-kernel.sh'

EOF
    exit 0
fi

if [ "$RUN_DOCKER" = "1" ]; then
    need docker
    need git

    if [ ! -d "$DOCKER_BUILD_ROOT" ]; then
        printf 'Missing T5 build root: %s\n' "$DOCKER_BUILD_ROOT" >&2
        exit 2
    fi
    if [ ! -f "$HOST_ANDROID_DIR/build/envsetup.sh" ]; then
        printf 'Missing T5 Android tree: %s\n' "$HOST_ANDROID_DIR" >&2
        exit 2
    fi

    if [ ! -d "$HOST_KERNEL_SRC/.git" ]; then
        if [ "$CLONE_KERNEL" != "1" ]; then
            printf 'Missing kernel source: %s\n' "$HOST_KERNEL_SRC" >&2
            printf 'Re-run with CLONE_KERNEL=1 RUN_DOCKER=1 to clone %s branch %s onto the T5.\n' "$KERNEL_REPO" "$KERNEL_BRANCH" >&2
            exit 2
        fi
        mkdir -p "$HOST_KERNEL_ROOT"
        git clone --branch "$KERNEL_BRANCH" --single-branch "$KERNEL_REPO" "$HOST_KERNEL_SRC"
    fi

    mkdir -p "$LOG_DIR"
    print_config | tee "$LOG_DIR/config.txt"

    exec docker run --rm \
        -v "$DOCKER_BUILD_ROOT:/android" \
        -v "$ROOT_DIR:/star2" \
        "$DOCKER_IMAGE" \
        bash -lc "set -euo pipefail; cd /star2; CONTAINER_ANDROID_DIR=$CONTAINER_ANDROID_DIR CONTAINER_KERNEL_SRC=$CONTAINER_KERNEL_SRC CONTAINER_KERNEL_OUT=$CONTAINER_KERNEL_OUT DEFCONFIG=$DEFCONFIG TARGETS=\"$TARGETS\" JOBS=$JOBS USE_CLANG=$USE_CLANG KCFLAGS=\"$KCFLAGS\" LOG_DIR=/star2/analysis/kernel-build-$STAMP ./scripts/kernel/build-sdm845-kernel.sh"
fi

ANDROID_DIR="${ANDROID_DIR:-$CONTAINER_ANDROID_DIR}"
KERNEL_SRC="${KERNEL_SRC:-$CONTAINER_KERNEL_SRC}"
KERNEL_OUT="${KERNEL_OUT:-$CONTAINER_KERNEL_OUT}"

if [ ! -f "$ANDROID_DIR/build/envsetup.sh" ]; then
    printf 'Missing Android tree inside container: %s\n' "$ANDROID_DIR" >&2
    exit 2
fi
if [ ! -f "$KERNEL_SRC/Makefile" ]; then
    printf 'Missing kernel source inside container: %s\n' "$KERNEL_SRC" >&2
    exit 2
fi

AARCH64_GCC="$ANDROID_DIR/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin"
ARM_GCC="$ANDROID_DIR/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin"
CLANG_BIN="$ANDROID_DIR/prebuilts/clang/host/linux-x86/clang-r416183b1/bin"
DTC_BIN="$ANDROID_DIR/prebuilts/misc/linux-x86/dtc/dtc"

if [ ! -x "$AARCH64_GCC/aarch64-linux-android-gcc" ]; then
    printf 'Missing aarch64 GCC toolchain: %s\n' "$AARCH64_GCC" >&2
    exit 2
fi
if [ ! -x "$ARM_GCC/arm-linux-androideabi-gcc" ]; then
    printf 'Missing arm32 GCC toolchain: %s\n' "$ARM_GCC" >&2
    exit 2
fi
if [ "$USE_CLANG" = "1" ] && [ ! -x "$CLANG_BIN/clang" ]; then
    printf 'Missing clang toolchain: %s\n' "$CLANG_BIN" >&2
    exit 2
fi

mkdir -p "$KERNEL_OUT" "$LOG_DIR"
print_config > "$LOG_DIR/config.txt"

export ARCH=arm64
export PATH="$AARCH64_GCC:$ARM_GCC:$CLANG_BIN:$ANDROID_DIR/prebuilts/misc/linux-x86/dtc:$PATH"

common_make=(
    -C "$KERNEL_SRC"
    O="$KERNEL_OUT"
    ARCH=arm64
    CROSS_COMPILE=aarch64-linux-android-
    CROSS_COMPILE_ARM32=arm-linux-androideabi-
    KCFLAGS="$KCFLAGS"
)

if [ -x "$DTC_BIN" ]; then
    common_make+=(DTC_EXT="$DTC_BIN")
fi

if [ "$USE_CLANG" = "1" ]; then
    common_make+=(CC=clang CLANG_TRIPLE=aarch64-linux-gnu-)
fi

{
    printf 'date=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'kernel_head=%s\n' "$(git -C "$KERNEL_SRC" rev-parse HEAD 2>/dev/null || true)"
    printf 'kernel_branch=%s\n' "$(git -C "$KERNEL_SRC" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    printf 'make_defconfig=make %q ' "${common_make[@]}"
    printf '%q\n' "$DEFCONFIG"
    printf 'make_targets=make %q ' "${common_make[@]}"
    printf -- '-j%q ' "$JOBS"
    # shellcheck disable=SC2086
    printf '%s\n' "$TARGETS"
} > "$LOG_DIR/session.txt"

make "${common_make[@]}" "$DEFCONFIG" 2>&1 | tee "$LOG_DIR/defconfig.log"

# shellcheck disable=SC2086
make "${common_make[@]}" -j"$JOBS" $TARGETS 2>&1 | tee "$LOG_DIR/build.log"

artifact="$KERNEL_OUT/arch/arm64/boot/Image.gz-dtb"
if [ -f "$artifact" ]; then
    sha256_file "$artifact" | tee "$LOG_DIR/SHA256SUMS"
    cp "$artifact" "$LOG_DIR/Image.gz-dtb"
    printf 'kernel_image=%s\n' "$artifact" | tee -a "$LOG_DIR/session.txt"
else
    printf 'Expected kernel artifact missing: %s\n' "$artifact" >&2
    exit 3
fi

find "$KERNEL_OUT/arch/arm64/boot/dts" -name '*.dtb' -type f -print 2>/dev/null | sort > "$LOG_DIR/dtb-files.txt" || true

printf 'Kernel build record: %s\n' "$LOG_DIR"
