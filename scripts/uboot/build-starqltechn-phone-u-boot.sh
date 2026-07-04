#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DOCKER_IMAGE="${DOCKER_IMAGE:-tinnci/sdm845-mainline-kernel-builder:ubuntu24.04}"
DOCKERFILE="${DOCKERFILE:-$ROOT_DIR/docker/sdm845-mainline-kernel-builder/Dockerfile}"
DOCKER_BUILD_IMAGE="${DOCKER_BUILD_IMAGE:-auto}"
DOCKER_BUILD_ROOT="${DOCKER_BUILD_ROOT:-/Volumes/gts7-android-build}"
CONTAINER_BUILD_ROOT="${CONTAINER_BUILD_ROOT:-/work/t5}"

UBOOT_REPO="${UBOOT_REPO:-https://github.com/Tinnci/u-boot.git}"
UBOOT_BRANCH="${UBOOT_BRANCH:-master}"
UBOOT_NAME="${UBOOT_NAME:-u-boot-master}"
HOST_UBOOT_ROOT="${HOST_UBOOT_ROOT:-$DOCKER_BUILD_ROOT/android/u-boot-builds}"
HOST_UBOOT_SRC="${HOST_UBOOT_SRC:-$HOST_UBOOT_ROOT/$UBOOT_NAME}"
HOST_UBOOT_OUT="${HOST_UBOOT_OUT:-$HOST_UBOOT_ROOT/out-u-boot-master-starqltechn-phone-gui}"
CONTAINER_UBOOT_SRC="${CONTAINER_UBOOT_SRC:-$CONTAINER_BUILD_ROOT/android/u-boot-builds/$UBOOT_NAME}"
CONTAINER_UBOOT_OUT="${CONTAINER_UBOOT_OUT:-$CONTAINER_BUILD_ROOT/android/u-boot-builds/out-u-boot-master-starqltechn-phone-gui}"

TARGET_CONFIGS="${TARGET_CONFIGS:-qcom_defconfig qcom-phone.config}"
DEFAULT_DEVICE_TREE="${DEFAULT_DEVICE_TREE:-qcom/sdm845-samsung-starqltechn}"
OF_LIST="${OF_LIST:-$DEFAULT_DEVICE_TREE}"
CLONE_UBOOT="${CLONE_UBOOT:-0}"
FETCH_UBOOT="${FETCH_UBOOT:-0}"
CLONE_DEPTH="${CLONE_DEPTH:-80}"
RUN_DOCKER="${RUN_DOCKER:-1}"
DRY_RUN="${DRY_RUN:-0}"
PACK_BOOTIMG="${PACK_BOOTIMG:-1}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '4')}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-auto}"
STAMP="${STAMP:-$(date -u '+%Y%m%d-%H%M%S')}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/analysis/u-boot-build-$STAMP}"

MKBOOTIMG_PY="${MKBOOTIMG_PY:-/Users/driezy/Downloads/gts7lwifi/analysis/tools-mkbootimg-aosp/mkbootimg.py}"
UNPACK_BOOTIMG_PY="${UNPACK_BOOTIMG_PY:-/Users/driezy/Downloads/gts7lwifi/analysis/tools-mkbootimg-aosp/unpack_bootimg.py}"
PMOS_BOOT_IMG="${PMOS_BOOT_IMG:-/Users/driezy/Downloads/star2qlte/packages/postmarketos/pmos_extracted/pmos/boot/boot.img}"
PMOS_FIT_IMAGE="${PMOS_FIT_IMAGE:-/Users/driezy/Downloads/star2qlte/packages/postmarketos/pmos_extracted/pmos/boot/boot_image.itb}"

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

docker_image_exists() {
    docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1
}

print_config() {
    printf 'root_dir=%s\n' "$ROOT_DIR"
    printf 'docker_image=%s\n' "$DOCKER_IMAGE"
    printf 'dockerfile=%s\n' "$DOCKERFILE"
    printf 'docker_build_image=%s\n' "$DOCKER_BUILD_IMAGE"
    printf 'docker_build_root=%s\n' "$DOCKER_BUILD_ROOT"
    printf 'container_build_root=%s\n' "$CONTAINER_BUILD_ROOT"
    printf 'uboot_repo=%s\n' "$UBOOT_REPO"
    printf 'uboot_branch=%s\n' "$UBOOT_BRANCH"
    printf 'uboot_name=%s\n' "$UBOOT_NAME"
    printf 'host_uboot_src=%s\n' "$HOST_UBOOT_SRC"
    printf 'host_uboot_out=%s\n' "$HOST_UBOOT_OUT"
    printf 'container_uboot_src=%s\n' "$CONTAINER_UBOOT_SRC"
    printf 'container_uboot_out=%s\n' "$CONTAINER_UBOOT_OUT"
    printf 'target_configs=%s\n' "$TARGET_CONFIGS"
    printf 'default_device_tree=%s\n' "$DEFAULT_DEVICE_TREE"
    printf 'of_list=%s\n' "$OF_LIST"
    printf 'clone_uboot=%s\n' "$CLONE_UBOOT"
    printf 'fetch_uboot=%s\n' "$FETCH_UBOOT"
    printf 'clone_depth=%s\n' "$CLONE_DEPTH"
    printf 'run_docker=%s\n' "$RUN_DOCKER"
    printf 'pack_bootimg=%s\n' "$PACK_BOOTIMG"
    printf 'jobs=%s\n' "$JOBS"
    printf 'source_date_epoch=%s\n' "$SOURCE_DATE_EPOCH"
    printf 'log_dir=%s\n' "$LOG_DIR"
    printf 'mkbootimg_py=%s\n' "$MKBOOTIMG_PY"
    printf 'unpack_bootimg_py=%s\n' "$UNPACK_BOOTIMG_PY"
    printf 'pmos_boot_img=%s\n' "$PMOS_BOOT_IMG"
    printf 'pmos_fit_image=%s\n' "$PMOS_FIT_IMAGE"
}

clone_uboot() {
    mkdir -p "$HOST_UBOOT_ROOT"

    if [ "$CLONE_DEPTH" = "0" ]; then
        git clone --single-branch --branch "$UBOOT_BRANCH" "$UBOOT_REPO" "$HOST_UBOOT_SRC"
    else
        git clone \
            --filter=blob:none \
            --depth "$CLONE_DEPTH" \
            --single-branch \
            --branch "$UBOOT_BRANCH" \
            "$UBOOT_REPO" \
            "$HOST_UBOOT_SRC"
    fi
}

package_boot_images() {
    need uv
    need gzip
    need tar

    if [ ! -f "$MKBOOTIMG_PY" ]; then
        printf 'Missing mkbootimg.py: %s\n' "$MKBOOTIMG_PY" >&2
        exit 2
    fi

    if [ ! -f "$HOST_UBOOT_OUT/u-boot-nodtb.bin" ]; then
        printf 'Missing U-Boot nodtb binary: %s\n' "$HOST_UBOOT_OUT/u-boot-nodtb.bin" >&2
        exit 2
    fi

    if [ ! -f "$HOST_UBOOT_OUT/u-boot.dtb" ]; then
        printf 'Missing U-Boot DTB: %s\n' "$HOST_UBOOT_OUT/u-boot.dtb" >&2
        exit 2
    fi

    mkdir -p "$LOG_DIR/packaged" "$LOG_DIR/packaging-work"
    gzip -n -c "$HOST_UBOOT_OUT/u-boot-nodtb.bin" > "$LOG_DIR/packaging-work/u-boot-nodtb.bin.gz"
    cat "$LOG_DIR/packaging-work/u-boot-nodtb.bin.gz" "$HOST_UBOOT_OUT/u-boot.dtb" > "$LOG_DIR/packaging-work/u-boot-nodtb.bin.gz-dtb"

    if [ -f "$UNPACK_BOOTIMG_PY" ] && [ -f "$PMOS_BOOT_IMG" ]; then
        rm -rf "$LOG_DIR/pmos-template-unpacked"
        mkdir -p "$LOG_DIR/pmos-template-unpacked"
        uv run python "$UNPACK_BOOTIMG_PY" \
            --boot_img "$PMOS_BOOT_IMG" \
            --out "$LOG_DIR/pmos-template-unpacked" \
            > "$LOG_DIR/pmos-template-unpack.txt"
    fi

    uv run python "$MKBOOTIMG_PY" \
        --kernel "$LOG_DIR/packaging-work/u-boot-nodtb.bin.gz-dtb" \
        --header_version 0 \
        --base 0x00000000 \
        --kernel_offset 0x00008000 \
        --ramdisk_offset 0x02000000 \
        --tags_offset 0x01e00000 \
        --pagesize 4096 \
        --output "$LOG_DIR/packaged/boot-u-boot-starqltechn-phone-gui-nofit.img" \
        > "$LOG_DIR/mkbootimg-nofit.log"

    if [ -f "$PMOS_FIT_IMAGE" ]; then
        uv run python "$MKBOOTIMG_PY" \
            --kernel "$LOG_DIR/packaging-work/u-boot-nodtb.bin.gz-dtb" \
            --ramdisk "$PMOS_FIT_IMAGE" \
            --header_version 0 \
            --base 0x00000000 \
            --kernel_offset 0x00008000 \
            --ramdisk_offset 0x02000000 \
            --tags_offset 0x01e00000 \
            --pagesize 4096 \
            --output "$LOG_DIR/packaged/boot-u-boot-starqltechn-phone-gui-pmosfit.img" \
            > "$LOG_DIR/mkbootimg-pmosfit.log"
    fi

    (
        cd "$LOG_DIR/packaged"
        rm -f SHA256SUMS
        for image in boot-u-boot-starqltechn-phone-gui-*.img; do
            [ -f "$image" ] || continue
            sha256_file "$image" >> SHA256SUMS
            tar -cf "${image%.img}.tar" "$image"
            sha256_file "${image%.img}.tar" >> SHA256SUMS
        done
    )

    ls -lh "$LOG_DIR/packaged" > "$LOG_DIR/packaged-ls.txt"
    if command -v file >/dev/null 2>&1; then
        file "$LOG_DIR"/packaged/* > "$LOG_DIR/packaged-file.txt"
    fi

    if [ -f "$UNPACK_BOOTIMG_PY" ]; then
        for image in "$LOG_DIR"/packaged/boot-u-boot-starqltechn-phone-gui-*.img; do
            [ -f "$image" ] || continue
            name="$(basename "$image" .img)"
            rm -rf "$LOG_DIR/unpack-$name"
            mkdir -p "$LOG_DIR/unpack-$name"
            uv run python "$UNPACK_BOOTIMG_PY" --boot_img "$image" --out "$LOG_DIR/unpack-$name" > "$LOG_DIR/unpack-$name.txt"
        done
    fi
}

if [ "$DRY_RUN" = "1" ]; then
    print_config
    cat <<EOF

Dry run complete.

Build or refresh the reusable Docker image:

  DOCKER_BUILD_IMAGE=1 RUN_DOCKER=1 $0

Clone and build U-Boot master for starqltechn phone UI:

  CLONE_UBOOT=1 RUN_DOCKER=1 $0

Fetch and rebuild an existing checkout:

  FETCH_UBOOT=1 RUN_DOCKER=1 $0

Package only from an existing output tree:

  RUN_DOCKER=0 PACK_ONLY=1 $0

EOF
    exit 0
fi

if [ "${PACK_ONLY:-0}" = "1" ]; then
    package_boot_images
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

    if [ ! -d "$HOST_UBOOT_SRC/.git" ]; then
        if [ "$CLONE_UBOOT" != "1" ]; then
            printf 'Missing U-Boot source: %s\n' "$HOST_UBOOT_SRC" >&2
            printf 'Re-run with CLONE_UBOOT=1 RUN_DOCKER=1 to clone %s branch %s.\n' "$UBOOT_REPO" "$UBOOT_BRANCH" >&2
            exit 2
        fi
        clone_uboot
    elif [ "$FETCH_UBOOT" = "1" ]; then
        git -C "$HOST_UBOOT_SRC" fetch --depth "$CLONE_DEPTH" origin "$UBOOT_BRANCH"
        git -C "$HOST_UBOOT_SRC" switch --detach FETCH_HEAD
    fi

    mkdir -p "$LOG_DIR"
    print_config | tee "$LOG_DIR/config.txt"

    docker run --rm \
        -v "$DOCKER_BUILD_ROOT:$CONTAINER_BUILD_ROOT" \
        -v "$ROOT_DIR:/workspace/g9650" \
        "$DOCKER_IMAGE" \
        bash -lc "set -euo pipefail; cd /workspace/g9650; UBOOT_SRC=$CONTAINER_UBOOT_SRC UBOOT_OUT=$CONTAINER_UBOOT_OUT TARGET_CONFIGS=\"$TARGET_CONFIGS\" DEFAULT_DEVICE_TREE=$DEFAULT_DEVICE_TREE OF_LIST=$OF_LIST JOBS=$JOBS SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH LOG_DIR=/workspace/g9650/analysis/u-boot-build-$STAMP RUN_DOCKER=0 PACK_BOOTIMG=0 ./scripts/uboot/build-starqltechn-phone-u-boot.sh"

    if [ "$PACK_BOOTIMG" = "1" ]; then
        package_boot_images
    fi
    exit 0
fi

UBOOT_SRC="${UBOOT_SRC:-$CONTAINER_UBOOT_SRC}"
UBOOT_OUT="${UBOOT_OUT:-$CONTAINER_UBOOT_OUT}"

if [ ! -f "$UBOOT_SRC/Makefile" ]; then
    printf 'Missing U-Boot source: %s\n' "$UBOOT_SRC" >&2
    exit 2
fi

if [ "$SOURCE_DATE_EPOCH" = "auto" ]; then
    SOURCE_DATE_EPOCH="$(git -C "$UBOOT_SRC" log -1 --format=%ct)"
fi
export SOURCE_DATE_EPOCH

mkdir -p "$UBOOT_OUT" "$LOG_DIR"
print_config > "$LOG_DIR/config.txt"

make_args=(-C "$UBOOT_SRC" O="$UBOOT_OUT" CROSS_COMPILE=aarch64-linux-gnu-)

{
    printf 'date=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'uboot_head=%s\n' "$(git -C "$UBOOT_SRC" rev-parse HEAD 2>/dev/null || true)"
    printf 'uboot_branch=%s\n' "$(git -C "$UBOOT_SRC" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    printf 'uboot_describe=%s\n' "$(git -C "$UBOOT_SRC" describe --tags --always --dirty 2>/dev/null || true)"
    printf 'source_date_epoch=%s\n' "$SOURCE_DATE_EPOCH"
    printf 'source_date_utc=%s\n' "$(date -u -d "@$SOURCE_DATE_EPOCH" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true)"
    printf 'make_defconfig='
    # shellcheck disable=SC2086
    print_shell_command make "${make_args[@]}" $TARGET_CONFIGS
    printf '\n'
    printf 'default_device_tree=%s\n' "$DEFAULT_DEVICE_TREE"
    printf 'of_list=%s\n' "$OF_LIST"
    printf 'make_build='
    print_shell_command make "${make_args[@]}" -j"$JOBS"
    printf '\n'
} > "$LOG_DIR/session.txt"

# shellcheck disable=SC2086
make "${make_args[@]}" $TARGET_CONFIGS 2>&1 | tee "$LOG_DIR/defconfig.log"
"$UBOOT_SRC/scripts/config" --file "$UBOOT_OUT/.config" --set-str DEFAULT_DEVICE_TREE "$DEFAULT_DEVICE_TREE"
"$UBOOT_SRC/scripts/config" --file "$UBOOT_OUT/.config" --set-str OF_LIST "$OF_LIST"
make "${make_args[@]}" olddefconfig 2>&1 | tee "$LOG_DIR/olddefconfig.log"
make "${make_args[@]}" -j"$JOBS" 2>&1 | tee "$LOG_DIR/build.log"

cp "$UBOOT_OUT/.config" "$LOG_DIR/u-boot.config"

{
    for artifact in \
        "$UBOOT_OUT/u-boot" \
        "$UBOOT_OUT/u-boot.bin" \
        "$UBOOT_OUT/u-boot-nodtb.bin" \
        "$UBOOT_OUT/u-boot.dtb" \
        "$UBOOT_OUT/u-boot.map"; do
        if [ -f "$artifact" ]; then
            sha256_file "$artifact"
        fi
    done
} | tee "$LOG_DIR/SHA256SUMS"

{
    printf 'Build complete.\n'
    printf 'Output: %s\n' "$UBOOT_OUT"
    printf 'Record: %s\n' "$LOG_DIR"
} | tee "$LOG_DIR/result.txt"
