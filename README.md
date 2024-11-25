# LicheeSG-Nano-Build

- updated linux, u-boot, middleware (cvi_mpi and SensorSupportList) and osdrv to sophgo weekly rls 2024.09.11
- merged mainline v5.10.226 into linux_5.10
- updated buildroot to 2024.05.3
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

# download source

```
git clone https://github.com/scpcom/LicheeSG-Nano-Build --depth=1
cd LicheeSG-Nano-Build
git submodule update --init --recursive --depth=1
```
You can remove the --depth=1 parameter to get full history.

## host environment

On Debian/Ubuntu you can install required packages with:
```
./host/prepare-host.sh
```

Or you can use container:

```
cd host/ubuntu
docker build -t licheervnano-build-ubuntu .
docker run --name licheervnano-build-ubuntu licheervnano-build-ubuntu
docker export licheervnano-build-ubuntu | sqfstar licheervnano-build-ubuntu.sqfs
singularity shell -e licheervnano-build-ubuntu.sqfs
```

# build it

```
source build/cvisetup.sh
# C906:
defconfig sg2002_licheervnano_sd
# A53:
# defconfig sg2002_licheea53nano_sd
build_all
```

# build fail

on some system, qt5svg or qt5base will build failed on first build, please retry command:

```
build_all
```

# how to modify image after build:

```
# first partition
touch wifi.sta
mcopy -i install/xxx/xxx.img@@1s wifi.sta ::/

# second partition
./host/mount_ext4.sh install/xxx/xxx.img mountpoint
cd mountpoint
touch xxx
```

# logo

```
./host/make_logo.sh input.jpeg logo.jpeg
mcopy -i install/xxx/xxx.img@@1s logo.jpeg ::/
```
