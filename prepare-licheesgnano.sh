#!/bin/bash -e

if [ "${SG_BOARD_FAMILY}/${SG_BOARD_LINK}" = "/" ]; then
  export SG_BOARD_FAMILY=sg200x
  export SG_BOARD_LINK=sg2002_licheervnano_sd
fi

if [ "configs/${BR_DEFCONFIG}" = "configs/" ]; then
  BR_DEFCONFIG=cvitek_SG200X_musl_riscv64_defconfig
  if echo ${SG_BOARD_LINK} | grep -q glibc_arm64 ; then
    BR_DEFCONFIG=cvitek_SG200X_64bit_defconfig
  fi
fi

if [ ! -e host-tools/gcc ]; then
  bash -e host/replace-all-thead-toolchains.sh
  #bash -e host/replace-all-linaro-toolchains.sh
  #bash -e host/replace-all-arm-toolchains.sh
fi

if git -C linux_5.10 checkout -b build 2>/dev/null ; then
  ln -sf ../../../../build/output/${SG_BOARD_LINK}/cvi_board_memmap.h linux_5.10/scripts/dtc/include-prefixes/cvi_board_memmap.h
  git -C linux_5.10 add scripts/dtc/include-prefixes/cvi_board_memmap.h
  for a in sg200x/sg2000_duo_sd sg200x/sg2002_duo_sd sg200x/sg2002_licheervnano_sd ${SG_BOARD_FAMILY}/${SG_BOARD_LINK} ; do
    d=`pwd`/build/boards/$a/dts_riscv
    [ -e $d ] || continue
    for f in $d/*.dts ; do
      b=`basename $f`
      ln -sf $d/$b linux_5.10/arch/riscv/boot/dts/cvitek/$b
      git -C linux_5.10 add -f arch/riscv/boot/dts/cvitek/$b
    done
  done
  for a in sg200x/sg2002_licheea53nano_sd sg200x/sg2000_wevb_sd ${SG_BOARD_FAMILY}/${SG_BOARD_LINK} ; do
    d=`pwd`/build/boards/$a/dts_arm
    [ -e $d ] || continue
    for f in $d/*.dts ; do
      b=`basename $f`
      ln -sf $d/$b linux_5.10/arch/arm/boot/dts/cvitek/$b
      git -C linux_5.10 add -f arch/arm/boot/dts/cvitek/$b
    done
  done
  for a in ${SG_BOARD_FAMILY}/${SG_BOARD_LINK} ; do
    d=`pwd`/build/boards/$a/dts_arm64
    [ -e $d ] || continue
    for f in $d/*.dts ; do
      b=`basename $f`
      ln -sf $d/$b linux_5.10/arch/arm64/boot/dts/cvitek/$b
      git -C linux_5.10 add -f arch/arm64/boot/dts/cvitek/$b
    done
  done
  d=`pwd`/build/boards/default/dts/${SG_BOARD_FAMILY}
  for f in $d/*.dtsi ; do
    b=`basename $f`
    ln -sf $d/$b linux_5.10/arch/riscv/boot/dts/cvitek/$b
    git -C linux_5.10 add -f arch/riscv/boot/dts/cvitek/$b
    ln -sf $d/$b linux_5.10/arch/arm/boot/dts/cvitek/$b
    git -C linux_5.10 add -f arch/arm/boot/dts/cvitek/$b
    ln -sf $d/$b linux_5.10/arch/arm64/boot/dts/cvitek/$b
    git -C linux_5.10 add -f arch/arm64/boot/dts/cvitek/$b
  done
  d=`pwd`/build/boards/default/dts/${SG_BOARD_FAMILY}_riscv
  for f in $d/*.dtsi ; do
    b=`basename $f`
    [ -e $d ] || continue
    ln -sf $d/$b linux_5.10/arch/riscv/boot/dts/cvitek/$b
    git -C linux_5.10 add -f arch/riscv/boot/dts/cvitek/$b
  done
  d=`pwd`/build/boards/default/dts/${SG_BOARD_FAMILY}_arm
  for f in $d/*.dtsi ; do
    b=`basename $f`
    [ -e $d ] || continue
    ln -sf $d/$b linux_5.10/arch/arm/boot/dts/cvitek/$b
    git -C linux_5.10 add -f arch/arm/boot/dts/cvitek/$b
    ln -sf $d/$b linux_5.10/arch/arm64/boot/dts/cvitek/$b
    git -C linux_5.10 add -f arch/arm64/boot/dts/cvitek/$b
  done
  git -C linux_5.10 commit -m "licheesgnano: symlink dts and memmap"
fi

if git -C u-boot-2021.10 checkout -b build 2>/dev/null ; then
  d=`pwd`/build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/u-boot
  ln -sf $d/cvi_board_init.c u-boot-2021.10/board/cvitek/cvi_board_init.c
  git -C u-boot-2021.10 add board/cvitek/cvi_board_init.c
  ln -sf $d/cvitek.h u-boot-2021.10/include/cvitek/cvitek.h
  git -C u-boot-2021.10 add include/cvitek/cvitek.h
  ln -sf ../../build/output/${SG_BOARD_LINK}/cvi_board_memmap.h u-boot-2021.10/include/cvi_board_memmap.h
  git -C u-boot-2021.10 add include/cvi_board_memmap.h
  git -C u-boot-2021.10 commit -m "licheesgnano: symlink dts and memmap"
fi

KERNEL_PATH=linux_5.10
KERNEL_TAG=`git -C ${KERNEL_PATH} describe --exact-match --tags HEAD 2>/dev/null || true`
[ "X$KERNEL_TAG" = "X" ] && git -C ${KERNEL_PATH} tag `date +%Y%m%d`
sed -i s/'describe --exact-match HEAD'/'describe --exact-match --tags HEAD'/g build/Makefile

if [ "${SG_BOARD_FAMILY}/${SG_BOARD_LINK}" != "/" ]; then
  cd build/
  git restore tools/common/sd_tools/genimage_rootless.cfg
  git restore tools/common/sd_tools/sd_gen_burn_image_rootless.sh
  if [ -e boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/genimage_rootless.cfg ] ;then
    cp -p boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/genimage_rootless.cfg tools/common/sd_tools/
  fi
  logopart=0
  if grep -q 'partition logo {' tools/common/sd_tools/genimage_rootless.cfg ; then
    logopart=1
  fi
  storagetype=sd
  if grep -q -E '^CONFIG_STORAGE_TYPE_emmc=y' boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig ; then
    storagetype=emmc
  fi
  if [ $storagetype != sd ]; then
    sed -i 's|rawimages/boot\.sd|rawimages/boot.'$storagetype'|g' tools/common/sd_tools/genimage_rootless.cfg
    sed -i 's|rawimages/boot\.sd|rawimages/boot.'$storagetype'|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
    sed -i 's|rootfs\.sd|rootfs.'$storagetype'|g' tools/common/sd_tools/genimage_rootless.cfg
    sed -i 's|rawimages/rootfs\.sd|rawimages/rootfs.'$storagetype'|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
    sed -i s/'\.img$'/'.zip'/g tools/common/sd_tools/sd_gen_burn_image_rootless.sh
    sed -i 's|^genimage$|cp -fv ${output_dir}/upgrade.zip ${output_dir}/images/${image}|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
    sed -i /'please use win32diskimager or dd'/d tools/common/sd_tools/sd_gen_burn_image_rootless.sh
  fi
  cd ..

  cd ramdisk/
  git restore initramfs/*/init
  [ $logopart = 0 ] || sed -i s/'mmcblk0p2'/'mmcblk0p3'/g initramfs/*/init
  cd ..

  cd buildroot/
  git restore board/cvitek/SG200X/overlay/etc/init.d/S99resizefs
  [ $logopart = 0 ] || sed -i s/'mmcblk0p2'/'mmcblk0p3'/g board/cvitek/SG200X/overlay/etc/init.d/S99resizefs
  [ $logopart = 0 ] || sed -i s/'resizepart 2 '/'resizepart 3 '/g board/cvitek/SG200X/overlay/etc/init.d/S99resizefs
  cd ..
fi

if [ "X$sdkver" != "X" ]; then
  sdkcros=linux-gnu
  sdklibc=`echo $sdkver | cut -d '_' -f 1`
  sdkarch=`echo $sdkver | cut -d '_' -f 2`
  sdktool=`echo $sdkver | tr a-z A-Z`
  oldcros=$sdkcros
  oldlibc=$sdklibc
  oldarch=$sdkarch
  # Allow to switch from ARM 32-bit to 64-bit and vice versa
  if [ $sdkver = glibc_arm64 ]; then
    oldarch=arm
  elif [ $sdkver = glibc_arm ]; then
    oldarch=arm64
  fi
  # Allow to switch from RISC-V musl to glibc and vice versa
  if [ $sdkver = musl_riscv64 ]; then
    sdkcros=linux-musl
    oldlibc=glibc
  elif [ $sdkver = glibc_riscv64 ]; then
    oldcros=linux-musl
    oldlibc=musl
  fi
  oldtool=`echo ${oldlibc}_${oldarch} | tr a-z A-Z`
  [ $oldarch = riscv64 ] && oldarch=riscv
  [ $sdkarch = riscv64 ] && sdkarch=riscv

  cd build
  if [ $sdkcros != $oldcros ]; then
    sed -i s/'-unknown-'${oldcros}'-'/'-unknown-'${sdkcros}'-'/g boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
  fi
  if [ $sdktool != $oldtool -a $sdkver != keep ]; then
    if ! grep -q -E '^CONFIG_TOOLCHAIN_.*=y' boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig ; then
      echo 'CONFIG_TOOLCHAIN_'${sdktool}'=y' >> boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
    else
      sed -i s/'^CONFIG_TOOLCHAIN_'${oldtool}'=y'/'CONFIG_TOOLCHAIN_'${sdktool}'=y'/g boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
    fi
  fi
  if [ $sdkarch != $oldarch ]; then
    if ! grep -q -E '^CONFIG_ARCH=".*"' boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig ; then
      echo 'CONFIG_ARCH="'${sdkarch}'"' >> boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
    else
      sed -i s/'^CONFIG_ARCH="'${oldarch}'"'/'CONFIG_ARCH="'${sdkarch}'"'/g boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
    fi
    if [ -e boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/dts_${oldarch} -a \
       ! -e boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/dts_${sdkarch} ]; then
      #ln -s dts_${oldarch} boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/dts_${sdkarch}
      mkdir -p boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/dts_${sdkarch}
      for f in boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/dts_${oldarch}/*.dts ; do
        b=`basename $f`
        ln -s ..//dts_${oldarch}/$b boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/dts_${sdkarch}/$b
      done
    fi
  fi
  cd ..
fi

cd buildroot/
if echo ${SG_BOARD_LINK} | grep -q milkv_duos ; then
  sed -i s/'BR2_PACKAGE_AIC8800_SDIO_FIRMWARE=y'/'BR2_PACKAGE_AIC8800_SDIO_FIRMWARE=y\nBR2_PACKAGE_AIC8800_SDIO_FIRMWARE_D80=y'/g configs/${BR_DEFCONFIG}
  sed -i s/'BR2_PACKAGE_CVI_PINMUX_SG200X=y'/'BR2_PACKAGE_CVI_PINMUX_SG200X=y\nBR2_PACKAGE_DUO_PINMUX_DUOS=y'/g configs/${BR_DEFCONFIG}
  sed -i s/'BR2_PACKAGE_CVI_PINMUX_SG200X=y'/'BR2_PACKAGE_CVI_PINMUX_SG200X=y\nBR2_PACKAGE_DUO_PINMUX=y'/g configs/${BR_DEFCONFIG}
elif echo ${SG_BOARD_LINK} | grep -q milkv_duo256m ; then
  sed -i s/'BR2_PACKAGE_CVI_PINMUX_SG200X=y'/'BR2_PACKAGE_CVI_PINMUX_SG200X=y\nBR2_PACKAGE_DUO_PINMUX_DUO256M=y'/g configs/${BR_DEFCONFIG}
  sed -i s/'BR2_PACKAGE_CVI_PINMUX_SG200X=y'/'BR2_PACKAGE_CVI_PINMUX_SG200X=y\nBR2_PACKAGE_DUO_PINMUX=y'/g configs/${BR_DEFCONFIG}
elif echo ${SG_BOARD_LINK} | grep -q milkv_duo ; then
  sed -i s/'BR2_PACKAGE_AIC8800_SDIO_FIRMWARE=y'/'BR2_PACKAGE_AIC8800_SDIO_FIRMWARE=y\nBR2_PACKAGE_AIC8800_SDIO_FIRMWARE_D80=y'/g configs/${BR_DEFCONFIG}
  sed -i s/'BR2_PACKAGE_CVI_PINMUX_SG200X=y'/'BR2_PACKAGE_CVI_PINMUX_SG200X=y\nBR2_PACKAGE_DUO_PINMUX_DUO=y'/g configs/${BR_DEFCONFIG}
  sed -i s/'BR2_PACKAGE_CVI_PINMUX_SG200X=y'/'BR2_PACKAGE_CVI_PINMUX_SG200X=y\nBR2_PACKAGE_DUO_PINMUX=y'/g configs/${BR_DEFCONFIG}
fi
cd ..

echo OK
