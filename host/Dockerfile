FROM ubuntu:noble as builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y eatmydata \
    && eatmydata apt-get install -y --no-install-recommends \
        qemu-user-static mtools sbuild-debian-developer-setup \
        binfmt-support gdisk kpartx sbuild \
        parted ca-certificates dh-make \
        autoconf automake autotools-dev bc \
        build-essential cmake cpio curl sudo \
        device-tree-compiler dosfstools e2fsprogs fdisk flex fuse2fs gawk  \
        git gperf kmod libexpat-dev \
        libgmp-dev liblzma-dev libmpc-dev libmpfr-dev libncurses-dev libssl-dev \
        libtool mmdebstrap ninja-build openssl parted tcl \
        patchutils python3 python3-dev  \
        python-is-python3 python3-jinja2 pkg-config xxd \
        python3-setuptools shellcheck swig gnupg \
        systemd-container texinfo zlib1g-dev wget arch-test \
        genimage joe mc unzip zip \
        fakeroot git kernel-wedge quilt ccache flex bison \
        libssl-dev dh-exec rsync libelf-dev bc gcc-riscv64-unknown-elf




FROM builder as build_image
WORKDIR /builder
ADD host/ /builder/

CMD ["/bin/bash"]
