# LicheeSG-Nano-Build

Builds for Sophgo cv181x/sg200x based boards such as MilkV Duo256/DuoS and Sipeed LicheeRvNano/NanoKVM. See also: https://github.com/scpcom/sophgo-sg200x-debian

# Running

This contains a drop-in replacement for [Sipeed NanoKVM](https://github.com/sipeed/NanoKVM). Download

`licheervnano-kvm_sd.img.xz`

from

https://github.com/scpcom/LicheeSG-Nano-Build/releases/

and burn the image to microSD card with something like Balena Etcher.

# Compatibility

Should work with:

[Some(?) NanoKVM products:](https://classic.sipeed.com/nanokvm)

1. Cube
2. Lite
3. PCIe

May work with:

Sophgo cv181x/sg200x based boards such as MilkV Duo256/DuoS. Try different releases.

# Changes from Upstream

- updated build, fsbl, opensbi, u-boot, linux, middleware (cvi_mpi and SensorSupportList) and osdrv to sophgo weekly rls 2024.10.14
- updated isp_tuning to sophgo weekly rls 2024.09.11
- updated freertos to sophgo weekly rls 2024.06.6 and ramdisk to sophgo weekly rls 2024.07.20
- merged mainline v5.10.235 into linux_5.10
- updated buildroot to 2025.02
- added maix_mmf sources and media_server submodule to middleware/sample/test_mmf
- imported rtsp_server from maixcdk to middleware/sample/test_mmf
- added support for nanokvm
- minimal fixes for a53 build
- Kept backward comptabibility for older middleware used by MaixCDK and NanoKVM app
- added build of NanoKVM server and web from source
- added flag to NanoKVM server to force download of libmaixcam_lib.so on first login
- added flag to NanoKVM server to disable tailscale
- imported maix_err, maix_fs and maix_log from MaixCDK and added functions to maix_mmf sources to build libmaixcam_lib.so replacement in middleware/sample/test_mmf
- added h264, vdec, maix_avc2flv and other functions to libmaixcam_lib.so
- created kvm_system replacement in middleware/sample/kvm_system as NanoKVM Full OLED controller
- created kvm_stream replacement in middleware/sample/kvm_stream for NanoKVM 2.0.9 and earlier
- created kvm_vision libkvm.so replacement in middleware/sample/test_mmf for NanoKVM 2.1.0 and later
- replaced download of NanoKVM latest.zip with nanokvm-skeleton git repo containing only non-binary files
- created dummy libs for ae, af, awb, cvi_json-c, cvi_miniz and isp_algo in middleware/modules/dummy to avoid usage of any pre-built closed source lib
- created light libs for cvi_bin, cvi_bin_isp and isp in middleware/modules/isp_light to reduce usage of dummy code
- dummy and light libs are currently only used in kvmapp folder for NanoKVM, the real libs are still required and used for the other projects with camera module
- added build of tailscale from source
- synced defconfig and dts from licheervnano to licheea53nano
- updated build scripts to compile the firmware (including MaixCDK and NanoKVM) for a53 mode (ARM 32-bit and 64-bit)
- added submodules to compile tpu sdk
- added compatibility for generic gnu toolchain (gcc/glibc) on all components (except tpu)
- created cvi_json-c and cvi_miniz open source replacement in middleware/modules/bin
- replaced host-tools by reproducible toolchain https://github.com/scpcom/riscv-gnu-toolchain/releases/tag/riscv64-gcc-thead_20230307-10.2.0-x86_64

# Compiling and building yourself

If you don't want to use the prebuilt packages, you can compile yourself.

## download source

```
git clone https://github.com/scpcom/LicheeSG-Nano-Build --depth=1
cd LicheeSG-Nano-Build
git submodule update --init --recursive --depth=1
```
You can remove the --depth=1 parameter to get full history.

## host environment

- OS: Debian 11/Ubuntu 22.04 or higher is recommended
- CPU: AMD/Intel x86_64 (for ARM aarch64 and others ./host/replace-all-thead-toolchains.sh maybe used)
- Memory: 8 GB RAM (Required to build opencv tests, all other can be complied with 4GB and below)
- Storage: 30GB free space minimum (plus optional 40GB to compile the toolchain)

On Debian/Ubuntu you can install required packages with:
```
./host/prepare-host.sh
```

Or you can use container:

```
docker build -t builder -f host/Dockerfile .
docker run --privileged -it --rm -v `pwd`/image:/output builder sh -e -c "BOARD_SHORT=licheervnano ./make_image.sh"
```

## build it

```
./build-licheervnano.sh
```

## build nanokvm

```
./build-nanokvm.sh
```

## build fail

on some systems, qt5svg or qt5base will fail on first build, please re-run the build command.

## how to modify image after build:

```
# first partition
touch wifi.sta
mcopy -i install/xxx/xxx.img@@1s wifi.sta ::/

# second partition
./host/mount_ext4.sh install/xxx/xxx.img mountpoint
cd mountpoint
touch xxx
```

## logo

```
./host/make_logo.sh input.jpeg logo.jpeg
mcopy -i install/xxx/xxx.img@@1s logo.jpeg ::/
```
