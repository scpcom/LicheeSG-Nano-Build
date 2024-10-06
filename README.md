# LicheeSG-Nano-Build

- updated linux, u-boot, middleware (cvi_mpi and SensorSupportList) and osdrv to sophgo weekly rls 2024.09.11
- merged mainline v5.10.226 into linux_5.10
- updated buildroot to 2024.05.3
- added maix_mmf sources and media_server submodule to middleware/sample/test_mmf
- imported rtsp_server from maixcdk to middleware/sample/test_mmf
- added support for nanokvm
- minimal fixes for a53 build
- Kept backward comptabibility for older middleware used by MaixCDK and NanoKVM app

# download source

```
git clone https://github.com/scpcom/LicheeSG-Nano-Build --depth=1
cd LicheeSG-Nano-Build
git submodule update --init --recursive --depth=1
```
You can remove the --depth=1 parameter to get full history.

## host environment

you can use container:

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
