#!/bin/sh -e
green="\e[0;32m"
red="\e[0;31m"
blue="\e[0;34m"
end_color="\e[0m"

[ "X$GIT_SOURCE_HOST" != "X" ] || GIT_SOURCE_HOST=github.com
[ "X$GIT_TARGET_HOST" != "X" ] || GIT_TARGET_HOST=$GIT_HOST
[ "X$GIT_SOURCE_USER" != "X" ] || GIT_SOURCE_USER=scpcom
[ "X$GIT_TARGET_USER" != "X" ] || GIT_TARGET_USER=$GIT_USER
[ "X$GIT_TARGET_USER" != "X" ] || GIT_TARGET_USER=$GIT_SOURCE_USER

if [ "X$GIT_TARGET_HOST" = "X" ]; then
  GIT_TARGET_HOST=$GIT_SOURCE_HOST
fi

GIT_SOURCE_USER_URL=https://$GIT_SOURCE_HOST/$GIT_SOURCE_USER
GIT_TARGET_USER_URL=https://$GIT_TARGET_HOST/$GIT_TARGET_USER
GIT_USER_URL=$GIT_TARGET_USER_URL

[ "X$GIT_REF" = "X" ] && GIT_REF="develop"

BUILDDIR="/cvi_mmf_sdk"

if [ "X$BOARD_SHORT" = "X" ]; then
echo "${red}BOARD_SHORT is not set${end_color}"
exit 1
fi

[ "X$STORAGE_TYPE" = "X" ] && STORAGE_TYPE="sd"
[ "X$VARIANT" = "X" ] && VARIANT="e"

[ "X$SDK_VER" = "X" ] && SDK_VER="musl_riscv64"
SDK_BOARD_FAMILY=sg200x
SDK_CHIP="sg2002"
SDK_BOARD="licheervnano"

if [ "${BOARD_SHORT}" = "duos" ]; then
SDK_CHIP=sg2000
SDK_BOARD=milkv_duos_${SDK_VER}
elif [ "${BOARD_SHORT}" = "duo256" ]; then
SDK_CHIP=sg2002
SDK_BOARD=milkv_duo256m_${SDK_VER}
elif [ "${BOARD_SHORT}" = "duo" ]; then
SDK_CHIP=cv1800b
SDK_BOARD=milkv_duo_${SDK_VER}
elif [ "${BOARD_SHORT}" = "licheea53nano" ]; then
[ $SDK_VER != "musl_riscv64" ] || SDK_VER="glibc_arm"
SDK_CHIP=sg2002
SDK_BOARD=licheea53nano
fi

SDK_BOARD_LINK=${SDK_CHIP}_${SDK_BOARD}_${STORAGE_TYPE}

if echo ${SDK_BOARD_LINK} | grep -q -E '^cv180' ; then
  SDK_BOARD_FAMILY=cv180x
fi
if echo ${SDK_BOARD_LINK} | grep -q -E '^sg200' ; then
  SDK_BOARD_FAMILY=sg200x
fi

BR_CHIP=$(echo ${SDK_BOARD_FAMILY} | tr a-z A-Z)
BR_SDK=${SDK_VER}

if [ "${SDK_VER}" = "glibc_arm64" ]; then
  BR_SDK=64bit
elif [ "${SDK_VER}" = "glibc_arm" ]; then
  BR_SDK=32bit
fi

BR_BOARD=cvitek_${BR_CHIP}_${BR_SDK}

BR_DEFCONFIG=${BR_BOARD}_defconfig

echo "${blue}Board: ${BOARD_SHORT}${end_color}"
echo "${blue}Variant: ${VARIANT}${end_color}"
echo "${blue}Storage: ${STORAGE_TYPE}${end_color}"
echo "${blue}Target: ${SDK_VER}${end_color}"
echo "${blue}Link: ${SDK_BOARD_LINK}${end_color}"

bs=${BUILDDIR}/sdk-prepare-checkout-stamp
if [ ! -e $bs ]; then
  echo "\n${green}Checking out SDK for ${BOARD_SHORT}${end_color}\n"
  git clone -b develop ${GIT_TARGET_USER_URL}/LicheeSG-Nano-Build ${BUILDDIR}
  cd ${BUILDDIR} && git checkout ${GIT_REF}
  if [ "${GIT_TARGET_HOST}" != "${GIT_SOURCE_HOST}" -o "${GIT_TARGET_USER}" != "${GIT_SOURCE_USER}" ]; then
    [ -e ${BUILDDIR}/host/mirror-clone.sh ] || cp /builder/mirror-clone.sh ${BUILDDIR}/host/
    cd ${BUILDDIR} && GIT_HOST=$GIT_TARGET_HOST GIT_USER=$GIT_TARGET_USER ./host/mirror-clone.sh
  else
    cd ${BUILDDIR} && git submodule update --init --recursive --depth=1
  fi
  git clone -b main --depth=1 ${GIT_USER_URL}/buildroot-dl.git ${BUILDDIR}/buildroot/dl
  cd ${BUILDDIR}/buildroot/dl && git checkout f5c041b
  cd ${BUILDDIR}/buildroot/dl && [ "${GIT_REF}" = "develop" ] || rm -rf .git
  touch $bs
fi

bs=${BUILDDIR}/sdk-prepare-patch-stamp
if [ ! -e $bs ]; then
  echo "\n${green}Patching SDK for ${BOARD_SHORT}${end_color}\n"
  [ "${TOOLCHAIN_URL}" = "X" ] || sed -i 's|^tcurl=.*|tcurl=${TOOLCHAIN_URL}|g' ${BUILDDIR}/host/replace-all-linaro-toolchains.sh
  [ "${TOOLCHAIN_URL}" = "X" ] || sed -i 's|^tcurl=.*|tcurl=${TOOLCHAIN_URL}|g' ${BUILDDIR}/host/replace-all-thead-toolchains.sh
  cd ${BUILDDIR} && ./host/prepare-host.sh
  cd ${BUILDDIR} && ./host/replace-all-thead-toolchains.sh
  if [ "${SDK_VER}" = "glibc_arm64" -o "${SDK_VER}" = "glibc_arm" ]; then
    cd ${BUILDDIR} && ./host/replace-all-linaro-toolchains.sh
  fi
  cd ${BUILDDIR} && rm -f host/riscv64-*.tar.*
  cd ${BUILDDIR}/buildroot && git am < /builder/buildroot-pkg-generic-cleanup-build-after-install.patch
  cd ${BUILDDIR}/buildroot && [ "$GIT_REF" = "develop" ] || git am < /builder/buildroot-cleanup-build-before-host-finalize.patch
  cd ${BUILDDIR}/buildroot && [ "$GIT_REF" = "develop" ] || git am < /builder/buildroot-cleanup-build-after-target-finalize.patch
  cd ${BUILDDIR}/buildroot && sed -i s/'BR2_PER_PACKAGE_DIRECTORIES=y'/'# BR2_PER_PACKAGE_DIRECTORIES is not set'/g configs/${BR_DEFCONFIG}
  cd ${BUILDDIR}/buildroot && git add configs/${BR_DEFCONFIG}
  cd ${BUILDDIR}/buildroot && git commit -m "disable per package directories"
  if [ "${GIT_TARGET_HOST}" != "${GIT_SOURCE_HOST}" -o "${GIT_TARGET_USER}" != "${GIT_SOURCE_USER}" ]; then
    #cd ${BUILDDIR}/buildroot && sed -i 's|^MAIX_CDK_RELEASES_URL = .*|MAIX_CDK_RELEASES_URL = '${GIT_RELEASES_URL}'|g' package/maix-cdk/maix-cdk.mk
    #cd ${BUILDDIR}/buildroot && sed -i 's|https://scpcom.github.io|'${USER_SITE_URL}'|g' package/nanokvm-server/nanokvm-server.mk
    #cd ${BUILDDIR}/buildroot && sed -i 's|https://scpcom.github.io|'${USER_SITE_URL}'|g' package/nanokvm-sg200x/nanokvm-sg200x.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/scpcom|'${GIT_USER_URL}'|g' package/maixcam-sg200x/maixcam-sg200x.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/scpcom|'${GIT_USER_URL}'|g' package/maix-cdk/maix-cdk.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/scpcom|'${GIT_USER_URL}'|g' package/nanokvm-server/nanokvm-server.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/scpcom|'${GIT_USER_URL}'|g' package/nanokvm-sg200x/nanokvm-sg200x.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/lxowalle|'${GIT_USER_URL}'|g' package/aic8800-sdio-firmware/aic8800-sdio-firmware.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/milkv-duo|'${GIT_USER_URL}'|g' package/duo-pinmux/duo-pinmux.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/0x754C|'${GIT_USER_URL}'|g' package/lcdtest/lcdtest.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/0x754C|'${GIT_USER_URL}'|g' package/tpudemo-sg200x/tpudemo-sg200x.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/sipeed|'${GIT_USER_URL}'|g' package/maix-cdk/maix-cdk.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/sipeed|'${GIT_USER_URL}'|g' package/maix-py/maix-py.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/sipeed|'${GIT_USER_URL}'|g' package/nanokvm-server/nanokvm-server.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/kmxz|'${GIT_USER_URL}'|g' package/overlayfs-tools/overlayfs-tools.mk
    cd ${BUILDDIR}/buildroot && sed -i 's|https://github.com/wlhe|'${GIT_USER_URL}'|g' package/uvc-gadget/uvc-gadget.mk
    cd ${BUILDDIR}/buildroot && git add package/aic8800-sdio-firmware/aic8800-sdio-firmware.mk
    cd ${BUILDDIR}/buildroot && git add package/duo-pinmux/duo-pinmux.mk
    cd ${BUILDDIR}/buildroot && git add package/lcdtest/lcdtest.mk
    cd ${BUILDDIR}/buildroot && git add package/maix-cdk/maix-cdk.mk
    cd ${BUILDDIR}/buildroot && git add package/maix-py/maix-py.mk
    cd ${BUILDDIR}/buildroot && git add package/maixcam-sg200x/maixcam-sg200x.mk
    cd ${BUILDDIR}/buildroot && git add package/nanokvm-server/nanokvm-server.mk
    cd ${BUILDDIR}/buildroot && git add package/nanokvm-sg200x/nanokvm-sg200x.mk
    cd ${BUILDDIR}/buildroot && git add package/overlayfs-tools/overlayfs-tools.mk
    cd ${BUILDDIR}/buildroot && git add package/tpudemo-sg200x/tpudemo-sg200x.mk
    cd ${BUILDDIR}/buildroot && git add package/uvc-gadget/uvc-gadget.mk
    cd ${BUILDDIR}/buildroot && git commit -m "update package urls"
    cd ${BUILDDIR}/tdl_sdk && sed -i 's|GIT_REPOSITORY https://github.com/google/googletest|GIT_REPOSITORY '${GIT_USER_URL}'/googletest|g' cmake/thirdparty.cmake
    cd ${BUILDDIR}/tdl_sdk && sed -i 's|GIT_REPOSITORY https://github.com/nothings/stb|GIT_REPOSITORY '${GIT_USER_URL}'/stb|g' cmake/thirdparty.cmake
    cd ${BUILDDIR}/tdl_sdk && sed -i 's|GIT_REPOSITORY https://gitlab.com/libeigen/eigen|GIT_REPOSITORY '${GIT_USER_URL}'/eigen|g' cmake/thirdparty.cmake
  fi
  cd ${BUILDDIR}/host-tools && for d in gcc/arm-gnu-toolchain-11.3.rel1-* gcc/gcc-buildroot-9.3.0-* gcc/gcc-linaro-6.3.1-2017.05-* ; do
    [ -e $d ] || continue
    [ "${SDK_VER}" != "glibc_arm64" -a "${SDK_VER}" != "glibc_arm" ] || if echo $d | grep -q gcc-linaro ; then continue ; fi
    echo "Removing $d"
    git rm -r $d || rm -rf $d
  done
  cd ${BUILDDIR}/host-tools && if [ "${SDK_VER}" != "glibc_riscv64" ]; then
    d=gcc/riscv64-linux-x86_64
    echo "Removing $d"
    git rm -r $d || rm -rf $d
    sed -i s/CROSS_COMPILE_GLIBC_RISCV64/CROSS_COMPILE_MUSL_RISCV64/g ${BUILDDIR}/fsbl/Makefile
  fi
  cd ${BUILDDIR}/host-tools && if [ "${SDK_VER}" != "musl_riscv64" ]; then
    d=gcc/riscv64-linux-musl-x86_64
    echo "Removing $d"
    git rm -r $d || rm -rf $d
  fi
  cd ${BUILDDIR}/middleware && git am < /builder/middleware-3rdparty-cleanup-build-after-install.patch
  cd ${BUILDDIR}/middleware && git am < /builder/middleware-3rdparty-deinit-submodules-after-install.patch
  cd ${BUILDDIR}/ramdisk && for f in rootfs/common_*/usr/share/fw_vcodec/*.bin ; do
    [ -e $f ] || continue
    d=`dirname $f`
    mkdir -p .backup-$d
    git mv $f .backup-$f
  done
  cd ${BUILDDIR}/ramdisk && for d in initramfs/uclibc_arm \
           rootfs/common_* rootfs/public sysroot/sysroot-glibc-linaro-2.23-2017.05-* ; do
    [ -e $d ] || continue
    [ "${SDK_VER}" != "glibc_arm64" -a "${SDK_VER}" != "glibc_arm" ] || if echo $d | grep -q glibc-linaro ; then continue ; fi
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
    cd ${BUILDDIR} && ./build-nanokvm.sh --board=${SDK_BOARD_LINK} --maixcdk --no-qt5
  elif [ "X${VARIANT}" = "Xdap" ]; then
    cd ${BUILDDIR} && ./build-dap.sh --board=${SDK_BOARD_LINK} --no-qt5
  else
    cd ${BUILDDIR} && ./build-licheervnano.sh --board=${SDK_BOARD_LINK} --maixcdk --maixpy --no-qt5
  fi
  touch $bs
fi

bs=${BUILDDIR}/sdk-output-stamp
if [ ! -e $bs ]; then
  cd ${BUILDDIR}/buildroot && [ "$GIT_REF" = "develop" ] || rm -rf dl
  cd ${BUILDDIR}/buildroot && rm -rf dl/aic8800-sdio-firmware/
  cd ${BUILDDIR}/buildroot && rm -rf dl/duo-pinmux/
  cd ${BUILDDIR}/buildroot && rm -rf dl/maixcam-sg200x/
  cd ${BUILDDIR}/buildroot && rm -rf dl/maix-cdk/
  cd ${BUILDDIR}/buildroot && rm -rf dl/nanokvm-server/
  cd ${BUILDDIR}/buildroot && rm -rf dl/nanokvm-sg200x/
  cd ${BUILDDIR}/buildroot && rm -rf dl/overlayfs-tools/
  cd ${BUILDDIR}/buildroot && rm -rf dl/uvc-gadget/
  cd ${BUILDDIR}/buildroot/output/${BR_BOARD} && rm -f images/rootfs.*
  cd ${BUILDDIR}/install/soc_${SDK_BOARD_LINK} && rm -f *.sd */*.sd
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
  if [ "${BOARD_SHORT}-${VARIANT}_${STORAGE_TYPE}" = "licheervnano-e_sd" ]; then
    cp ${BUILDDIR}/install/soc_${SDK_BOARD_LINK}/maixcam-latest.zip /output/
    cd ${BUILDDIR}/oss && zip -r /output/oss.zip oss_release_tarball run_build.sh
  fi
  echo "\n${green}Image for ${BOARD_SHORT} is ${BOARD_SHORT}-${VARIANT}_${STORAGE_TYPE}.img.xz${end_color}\n"
  touch $bs
fi
