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
        python3-dev \
        python3-setuptools \
        rsync \
        swig \
        uuid-dev \
        libgnutls28-dev \
        xxd \
        xz-utils \
        zstd && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
