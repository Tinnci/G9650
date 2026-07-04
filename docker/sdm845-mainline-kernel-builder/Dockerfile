FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bc \
        bison \
        build-essential \
        ca-certificates \
        clang \
        cpio \
        device-tree-compiler \
        dwarves \
        file \
        flex \
        gcc-aarch64-linux-gnu \
        git \
        kmod \
        libelf-dev \
        libssl-dev \
        lld \
        llvm \
        make \
        perl \
        pkg-config \
        python3 \
        rsync \
        xz-utils \
        zstd && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

