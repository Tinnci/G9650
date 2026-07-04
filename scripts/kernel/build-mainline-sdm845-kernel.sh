#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DOCKER_IMAGE="${DOCKER_IMAGE:-tinnci/sdm845-mainline-kernel-builder:ubuntu24.04}"
DOCKERFILE="${DOCKERFILE:-$ROOT_DIR/docker/sdm845-mainline-kernel-builder/Dockerfile}"
DOCKER_BUILD_IMAGE="${DOCKER_BUILD_IMAGE:-auto}"
DOCKER_BUILD_ROOT="${DOCKER_BUILD_ROOT:-/Volumes/gts7-android-build}"
CONTAINER_BUILD_ROOT="${CONTAINER_BUILD_ROOT:-/work/t5}"

KERNEL_REPO="${KERNEL_REPO:-https://gitlab.com/dsankouski/sdm845-linux-next.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:-6.17-wip/starqltechn_latest_patches}"
KERNEL_NAME="${KERNEL_NAME:-mainline-sdm845-linux-next-starqltechn_latest_patches}"
HOST_KERNEL_ROOT="${HOST_KERNEL_ROOT:-$DOCKER_BUILD_ROOT/android/kernel-builds/sdm845}"
HOST_KERNEL_SRC="${HOST_KERNEL_SRC:-$HOST_KERNEL_ROOT/$KERNEL_NAME}"
HOST_KERNEL_OUT="${HOST_KERNEL_OUT:-$HOST_KERNEL_ROOT/out-mainline-starqltechn}"
CONTAINER_KERNEL_SRC="${CONTAINER_KERNEL_SRC:-$CONTAINER_BUILD_ROOT/android/kernel-builds/sdm845/$KERNEL_NAME}"
CONTAINER_KERNEL_OUT="${CONTAINER_KERNEL_OUT:-$CONTAINER_BUILD_ROOT/android/kernel-builds/sdm845/out-mainline-starqltechn}"

CLONE_KERNEL="${CLONE_KERNEL:-0}"
FETCH_KERNEL="${FETCH_KERNEL:-0}"
CLONE_DEPTH="${CLONE_DEPTH:-80}"
RUN_DOCKER="${RUN_DOCKER:-1}"
DRY_RUN="${DRY_RUN:-0}"
USE_LLVM="${USE_LLVM:-1}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '4')}"
CONFIG_FRAGMENT="${CONFIG_FRAGMENT:-arch/arm64/configs/sdm845.config}"
DISABLE_LOCALVERSION_AUTO="${DISABLE_LOCALVERSION_AUTO:-1}"
DTB_TARGET="${DTB_TARGET:-qcom/sdm845-samsung-starqltechn.dtb}"
BUILD_ALL_DTBS="${BUILD_ALL_DTBS:-0}"
if [ "${TARGETS+set}" != "set" ]; then
    if [ "$BUILD_ALL_DTBS" = "1" ]; then
        TARGETS="Image.gz dtbs"
    else
        TARGETS="Image.gz $DTB_TARGET"
    fi
fi
STAMP="${STAMP:-$(date -u '+%Y%m%d-%H%M%S')}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/analysis/mainline-kernel-build-$STAMP}"

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$1" >&2
        exit 1
    fi
}

print_shell_command() {
    printf '%q' "$1"
    shift
    for arg in "$@"; do
        printf ' %q' "$arg"
    done
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
    printf 'dockerfile=%s\n' "$DOCKERFILE"
    printf 'docker_build_image=%s\n' "$DOCKER_BUILD_IMAGE"
    printf 'docker_build_root=%s\n' "$DOCKER_BUILD_ROOT"
    printf 'container_build_root=%s\n' "$CONTAINER_BUILD_ROOT"
    printf 'kernel_repo=%s\n' "$KERNEL_REPO"
    printf 'kernel_branch=%s\n' "$KERNEL_BRANCH"
    printf 'kernel_name=%s\n' "$KERNEL_NAME"
    printf 'host_kernel_src=%s\n' "$HOST_KERNEL_SRC"
    printf 'host_kernel_out=%s\n' "$HOST_KERNEL_OUT"
    printf 'container_kernel_src=%s\n' "$CONTAINER_KERNEL_SRC"
    printf 'container_kernel_out=%s\n' "$CONTAINER_KERNEL_OUT"
    printf 'clone_kernel=%s\n' "$CLONE_KERNEL"
    printf 'fetch_kernel=%s\n' "$FETCH_KERNEL"
    printf 'clone_depth=%s\n' "$CLONE_DEPTH"
    printf 'run_docker=%s\n' "$RUN_DOCKER"
    printf 'use_llvm=%s\n' "$USE_LLVM"
    printf 'jobs=%s\n' "$JOBS"
    printf 'config_fragment=%s\n' "$CONFIG_FRAGMENT"
    printf 'disable_localversion_auto=%s\n' "$DISABLE_LOCALVERSION_AUTO"
    printf 'dtb_target=%s\n' "$DTB_TARGET"
    printf 'build_all_dtbs=%s\n' "$BUILD_ALL_DTBS"
    printf 'targets=%s\n' "$TARGETS"
    printf 'log_dir=%s\n' "$LOG_DIR"
}

docker_image_exists() {
    docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1
}

clone_kernel() {
    mkdir -p "$HOST_KERNEL_ROOT"

    if [ "$CLONE_DEPTH" = "0" ]; then
        git clone --single-branch --branch "$KERNEL_BRANCH" "$KERNEL_REPO" "$HOST_KERNEL_SRC"
    else
        git clone \
            --filter=blob:none \
            --depth "$CLONE_DEPTH" \
            --single-branch \
            --branch "$KERNEL_BRANCH" \
            "$KERNEL_REPO" \
            "$HOST_KERNEL_SRC"
    fi
}

if [ "$DRY_RUN" = "1" ]; then
    print_config
    cat <<EOF

Dry run complete.

Build or refresh the reusable Docker image:

  DOCKER_BUILD_IMAGE=1 RUN_DOCKER=1 $0

Clone the latest selected mainline branch to the T5 and build:

  CLONE_KERNEL=1 RUN_DOCKER=1 $0

Build the full arm64 DTB set instead of the fast starqltechn DTB target:

  BUILD_ALL_DTBS=1 CLONE_KERNEL=1 RUN_DOCKER=1 $0

Reuse an existing checkout, fetch the selected branch, and build:

  FETCH_KERNEL=1 RUN_DOCKER=1 $0

Fallback to the older XDA branch:

  KERNEL_BRANCH=starqltechn_for_xda KERNEL_NAME=mainline-sdm845-linux-next-starqltechn_for_xda CLONE_KERNEL=1 RUN_DOCKER=1 $0

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

    if [ "$DOCKER_BUILD_IMAGE" = "1" ] || { [ "$DOCKER_BUILD_IMAGE" = "auto" ] && ! docker_image_exists; }; then
        docker build -t "$DOCKER_IMAGE" -f "$DOCKERFILE" "$ROOT_DIR"
    fi

    if [ ! -d "$HOST_KERNEL_SRC/.git" ]; then
        if [ "$CLONE_KERNEL" != "1" ]; then
            printf 'Missing kernel source: %s\n' "$HOST_KERNEL_SRC" >&2
            printf 'Re-run with CLONE_KERNEL=1 RUN_DOCKER=1 to clone %s branch %s.\n' "$KERNEL_REPO" "$KERNEL_BRANCH" >&2
            exit 2
        fi
        clone_kernel
    elif [ "$FETCH_KERNEL" = "1" ]; then
        git -C "$HOST_KERNEL_SRC" fetch --depth "$CLONE_DEPTH" origin "$KERNEL_BRANCH"
        git -C "$HOST_KERNEL_SRC" switch --detach FETCH_HEAD
    fi

    mkdir -p "$LOG_DIR"
    print_config | tee "$LOG_DIR/config.txt"

    exec docker run --rm \
        -v "$DOCKER_BUILD_ROOT:$CONTAINER_BUILD_ROOT" \
        -v "$ROOT_DIR:/workspace/g9650" \
        "$DOCKER_IMAGE" \
        bash -lc "set -euo pipefail; cd /workspace/g9650; KERNEL_SRC=$CONTAINER_KERNEL_SRC KERNEL_OUT=$CONTAINER_KERNEL_OUT USE_LLVM=$USE_LLVM JOBS=$JOBS CONFIG_FRAGMENT=$CONFIG_FRAGMENT DISABLE_LOCALVERSION_AUTO=$DISABLE_LOCALVERSION_AUTO DTB_TARGET=$DTB_TARGET BUILD_ALL_DTBS=$BUILD_ALL_DTBS TARGETS=\"$TARGETS\" LOG_DIR=/workspace/g9650/analysis/mainline-kernel-build-$STAMP RUN_DOCKER=0 ./scripts/kernel/build-mainline-sdm845-kernel.sh"
fi

KERNEL_SRC="${KERNEL_SRC:-$CONTAINER_KERNEL_SRC}"
KERNEL_OUT="${KERNEL_OUT:-$CONTAINER_KERNEL_OUT}"

if [ ! -f "$KERNEL_SRC/Makefile" ]; then
    printf 'Missing kernel source: %s\n' "$KERNEL_SRC" >&2
    exit 2
fi

mkdir -p "$KERNEL_OUT" "$LOG_DIR"
print_config > "$LOG_DIR/config.txt"

export ARCH=arm64
make_args=(-C "$KERNEL_SRC" O="$KERNEL_OUT" ARCH=arm64)

if [ "$USE_LLVM" = "1" ]; then
    make_args+=(LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu-)
else
    make_args+=(CROSS_COMPILE=aarch64-linux-gnu-)
fi

{
    printf 'date=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'kernel_head=%s\n' "$(git -C "$KERNEL_SRC" rev-parse HEAD 2>/dev/null || true)"
    printf 'kernel_branch=%s\n' "$(git -C "$KERNEL_SRC" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    printf 'make_defconfig='
    print_shell_command make "${make_args[@]}" defconfig
    printf '\n'
    printf 'config_fragment=%s\n' "$CONFIG_FRAGMENT"
    printf 'disable_localversion_auto=%s\n' "$DISABLE_LOCALVERSION_AUTO"
    printf 'make_targets='
    # shellcheck disable=SC2086
    print_shell_command make "${make_args[@]}" -j"$JOBS" $TARGETS
    printf '\n'
} > "$LOG_DIR/session.txt"

make "${make_args[@]}" defconfig 2>&1 | tee "$LOG_DIR/defconfig.log"

fragment_path="$KERNEL_SRC/$CONFIG_FRAGMENT"
if [ -f "$fragment_path" ]; then
    "$KERNEL_SRC/scripts/kconfig/merge_config.sh" \
        -m \
        -O "$KERNEL_OUT" \
        "$KERNEL_OUT/.config" \
        "$fragment_path" 2>&1 | tee "$LOG_DIR/merge-config.log"

    if [ "$DISABLE_LOCALVERSION_AUTO" = "1" ]; then
        "$KERNEL_SRC/scripts/config" \
            --file "$KERNEL_OUT/.config" \
            --disable LOCALVERSION_AUTO
    fi
    make "${make_args[@]}" olddefconfig 2>&1 | tee "$LOG_DIR/olddefconfig.log"
else
    printf 'Config fragment not found, continuing with defconfig only: %s\n' "$fragment_path" | tee "$LOG_DIR/merge-config.log"
fi

# shellcheck disable=SC2086
make "${make_args[@]}" -j"$JOBS" $TARGETS 2>&1 | tee "$LOG_DIR/build.log"

boot_dir="$KERNEL_OUT/arch/arm64/boot"
{
    for artifact in "$boot_dir/Image.gz" "$boot_dir/Image" "$boot_dir/dts/qcom/sdm845-samsung-starqltechn.dtb"; do
        if [ -f "$artifact" ]; then
            sha256_file "$artifact"
        fi
    done
} | tee "$LOG_DIR/SHA256SUMS"

find "$boot_dir/dts" -name '*.dtb' -type f -print 2>/dev/null | sort > "$LOG_DIR/dtb-files.txt" || true

if [ ! -f "$boot_dir/Image.gz" ]; then
    printf 'Expected kernel artifact missing: %s\n' "$boot_dir/Image.gz" >&2
    exit 3
fi

printf 'Mainline kernel build record: %s\n' "$LOG_DIR"
