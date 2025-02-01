#!/bin/sh -e
green="\e[0;32m"
red="\e[0;31m"
blue="\e[0;34m"
end_color="\e[0m"

[ "X$GIT_REF" = "X" ] && GIT_REF="develop"

BUILDDIR="/cvi_mmf_sdk"

if [ "X$BOARD_SHORT" = "X" ]; then
echo "${red}BOARD_SHORT is not set${end_color}"
exit 1
fi

[ "X$STORAGE_TYPE" = "X" ] && STORAGE_TYPE="sd"
[ "X$VARIANT" = "X" ] && VARIANT="e"

[ "X$SDK_VER" = "X" ] && SDK_VER="musl_riscv64"
SDK_CHIP="sg2002"
SDK_BOARD="licheervnano"

if [ "${BOARD_SHORT}" = "duos" ]; then
SDK_CHIP=sg2000
SDK_BOARD=milkv_duos_${SDK_VER}
elif [ "${BOARD_SHORT}" = "duo256" ]; then
SDK_CHIP=sg2002
SDK_BOARD=milkv_duo256m_${SDK_VER}
fi

SDK_BOARD_LINK=${SDK_CHIP}_${SDK_BOARD}_${STORAGE_TYPE}

BR_DEFCONFIG=cvitek_SG200X_${SDK_VER}_defconfig

echo "${blue}Board: ${BOARD_SHORT}${end_color}"
echo "${blue}Variant: ${VARIANT}${end_color}"
echo "${blue}Storage: ${STORAGE_TYPE}${end_color}"
echo "${blue}Link: ${SDK_BOARD_LINK}${end_color}"

bs=${BUILDDIR}/sdk-prepare-checkout-stamp
if [ ! -e $bs ]; then
  echo "\n${green}Checking out SDK for ${BOARD_SHORT}${end_color}\n"
  git clone -b develop https://github.com/scpcom/LicheeSG-Nano-Build ${BUILDDIR}
  cd ${BUILDDIR} && git checkout ${GIT_REF}
  cd ${BUILDDIR} && git submodule update --init --recursive --depth=1
  touch $bs
fi

bs=${BUILDDIR}/sdk-prepare-patch-stamp
if [ ! -e $bs ]; then
  echo "\n${green}Patching SDK for ${BOARD_SHORT}${end_color}\n"
  cd ${BUILDDIR} && ./host/prepare-host.sh
  cd ${BUILDDIR}/buildroot && git am < /builder/buildroot-pkg-generic-cleanup-build-after-install.patch
  cd ${BUILDDIR}/buildroot && sed -i s/'BR2_PER_PACKAGE_DIRECTORIES=y'/'# BR2_PER_PACKAGE_DIRECTORIES is not set'/g configs/${BR_DEFCONFIG}
  cd ${BUILDDIR}/buildroot && git add configs/${BR_DEFCONFIG}
  cd ${BUILDDIR}/buildroot && git commit -m "disable per package directories"
  cd ${BUILDDIR}/host-tools && for d in gcc/arm-gnu-toolchain-11.3.rel1-* gcc/gcc-buildroot-9.3.0-* gcc/gcc-linaro-6.3.1-2017.05-* ; do
    [ -e $d ] || continue
    git rm -r $d
  done
  cd ${BUILDDIR}/host-tools && if [ "${SDK_VER}" != "glibc_riscv64" ]; then
    git rm -r gcc/riscv64-linux-x86_64
    sed -i s/CROSS_COMPILE_GLIBC_RISCV64/CROSS_COMPILE_MUSL_RISCV64/g ${BUILDDIR}/fsbl/Makefile
  fi
  cd ${BUILDDIR}/host-tools && if [ "${SDK_VER}" != "musl_riscv64" ]; then
    git rm -r gcc/riscv64-linux-musl-x86_64
  fi
  cd ${BUILDDIR}/ramdisk && for f in rootfs/common_*/usr/share/fw_vcodec/*.bin ; do
    [ -e $f ] || continue
    d=`dirname $f`
    mkdir -p .backup-$d
    git mv $f .backup-$f
  done
  cd ${BUILDDIR}/ramdisk && for d in initramfs/uclibc_arm \
           rootfs/common_* rootfs/public sysroot/sysroot-glibc-linaro-2.23-2017.05-* ; do
    [ -e $d ] || continue
    git rm -r $d
  done
  cd ${BUILDDIR}/ramdisk && for f in .backup-rootfs/common_*/usr/share/fw_vcodec/*.bin ; do
    [ -e $f ] || continue
    b=`basename $f`
    d=`dirname $f | cut -d '-' -f 2-`
    mkdir -p $d
    git mv $f $d/$b
  done
  cd ${BUILDDIR}/ramdisk && rm -rf .backup-rootfs/
  touch $bs
fi

bs=${BUILDDIR}/sdk-compile-stamp
if [ ! -e $bs ]; then
  echo "\n${green}Building SDK for ${BOARD_SHORT}${end_color}\n"
  if [ "X${VARIANT}" = "Xkvm" ]; then
    cd ${BUILDDIR} && ./build-nanokvm.sh --board=${SDK_BOARD_LINK}
  else
    cd ${BUILDDIR} && ./build-licheervnano.sh --board=${SDK_BOARD_LINK}
  fi
  touch $bs
fi

bs=${BUILDDIR}/sdk-output-stamp
if [ ! -e $bs ]; then
  echo "\n${green}Packing Image for ${BOARD_SHORT}${end_color}\n"
  for f in ${BUILDDIR}/install/soc_${SDK_BOARD_LINK}/images/*.img ; do
    [ -e $f ] || continue
    xz -9 -c -f $f > /output/${BOARD_SHORT}-${VARIANT}_${STORAGE_TYPE}.img.xz
    break
  done
  if [ "X${VARIANT}" = "Xkvm" ]; then
    cp ${BUILDDIR}/install/soc_${SDK_BOARD_LINK}/nanokvm-latest.zip /output/
  else
    cp ${BUILDDIR}/install/soc_${SDK_BOARD_LINK}/*.bin /output/
    rm -f /output/fw_payload*.bin
    cd /output/ && zip ${BOARD_SHORT}-${VARIANT}_${STORAGE_TYPE}-fip.zip *.bin
    rm -f /output/*.bin
  fi
  echo "\n${green}Image for ${BOARD_SHORT} is ${BOARD_SHORT}-${VARIANT}_${STORAGE_TYPE}.img.xz${end_color}\n"
  touch $bs
fi
