#!/bin/bash -e

export SG_BOARD_FAMILY=sg200x
export SG_BOARD_LINK=sg2002_licheervnano_sd

sdkver=keep
maixcdk=n
nanokvm=y
tailscale=n
tpudemo=n
tpusdk=n
while [ "$#" -gt 0 ]; do
	case "$1" in
	--board=*|--board-link=*)
		export SG_BOARD_LINK=`echo $1 | cut -d '=' -f 2-`
		shift
		;;
	--sdk-ver=*|--sdkver=*)
		sdkver=`echo $1 | cut -d '=' -f 2-`
		shift
		;;
	--maix-cdk|--maixcdk)
		shift
		maixcdk=y
		;;
	--no-maix-cdk|--no-maixcdk)
		shift
		maixcdk=n
		;;
	--tailscale)
		shift
		tailscale=y
		;;
	--no-tailscale)
		shift
		tailscale=n
		;;
	--tpu-demo|--tpudemo)
		shift
		tpudemo=y
		;;
	--no-tpu-demo|--no-tpudemo)
		shift
		tpudemo=n
		;;
	--tpu-sdk|--tpusdk)
		shift
		tpusdk=y
		;;
	--no-tpu-sdk|--no-tpusdk)
		shift
		tpusdk=n
		;;
	*)
		break
		;;
	esac
done

for p in / /usr/ /usr/local/ ; do
  if echo $PATH | grep -q ${p}bin ; then
    if ! echo $PATH | grep -q ${p}sbin ; then
      export PATH=${p}sbin:$PATH
    fi
  fi
done

if echo ${SG_BOARD_LINK} | grep -q -E '^cv180' ; then
  export SG_BOARD_FAMILY=cv180x
fi
if echo ${SG_BOARD_LINK} | grep -q -E '^sg200' ; then
  export SG_BOARD_FAMILY=sg200x
fi

if [ -e prepare-licheesgnano.sh ]; then
  bash -e prepare-licheesgnano.sh
fi

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
if [ $sdktool != $oldtool ]; then
  sed -i s/'^CONFIG_TOOLCHAIN_'${oldtool}'=y'/'CONFIG_TOOLCHAIN_'${sdktool}'=y'/g boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
fi
if [ $sdkarch != $oldarch ]; then
  sed -i s/'^CONFIG_ARCH="'${oldarch}'"'/'CONFIG_ARCH="'${sdkarch}'"'/g boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
  [ -e boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/dts_${oldarch} -a \
  ! -e boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/dts_${sdkarch} ] && ln -s dts_${oldarch} boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/dts_${sdkarch}
fi
# Expand user space RAM from 128MB to 160MB
sed -i s/'ION_SIZE = .* . SIZE_1M'/'ION_SIZE = 75 * SIZE_1M'/g boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/memmap.py
sed -i s/'BOOTLOGO_SIZE = .* . SIZE_1K'/'BOOTLOGO_SIZE = 5632 * SIZE_1K'/g boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/memmap.py
# board config for maixcdk
if [ $maixcdk = y ]; then
  if ! grep -q "board" tools/common/sd_tools/genimage_rootless.cfg ; then
    sed -i s/'\t\t\t"usb.dev",'/'\t\t\t"usb.dev",\n\t\t\t"board",'/g tools/common/sd_tools/genimage_rootless.cfg
  fi
  if ! grep -q "board" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
    sed -i 's| \${output_dir}/input/usb.dev$| ${output_dir}/input/usb.dev\necho "id=maixcam" > ${output_dir}/input/board\necho "panel=st7701_hd228001c31" >> ${output_dir}/input/board|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
  fi
fi
# set mipi sensor flag
if echo ${SG_BOARD_LINK} | grep -q lichee ; then
  sed -i /epsilon/d tools/common/sd_tools/genimage_rootless.cfg
  sed -i /epsilon/d tools/common/sd_tools/sd_gen_burn_image_rootless.sh
else
  if ! grep -q "epsilon" tools/common/sd_tools/genimage_rootless.cfg ; then
    sed -i s/'\t\t\t"usb.dev",'/'\t\t\t"usb.dev",\n\t\t\t"epsilon",'/g tools/common/sd_tools/genimage_rootless.cfg
  fi
  if ! grep -q "epsilon" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
    sed -i 's| \${output_dir}/input/usb.dev$| ${output_dir}/input/usb.dev\ntouch ${output_dir}/input/epsilon|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
  fi
fi
# enable usb disk, disable ncm
sed -i s/'usb.ncm'/'usb.disk0'/g tools/common/sd_tools/genimage_rootless.cfg
sed -i 's|touch ${output_dir}/input/usb.ncm|echo /dev/mmcblk0p3 > ${output_dir}/input/usb.disk0|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
# enable usb hid
#if ! grep -q "usb.hid" tools/common/sd_tools/genimage_rootless.cfg ; then
#  sed -i s/'\t\t\t"usb.disk0",'/'\t\t\t"usb.disk0",\n\t\t\t"usb.hid",'/g tools/common/sd_tools/genimage_rootless.cfg
#fi
if ! grep -q "usb.touchpad" tools/common/sd_tools/genimage_rootless.cfg ; then
  sed -i s/'\t\t\t"usb.disk0",'/'\t\t\t"usb.disk0",\n\t\t\t"usb.touchpad",'/g tools/common/sd_tools/genimage_rootless.cfg
fi
if ! grep -q "usb.mouse" tools/common/sd_tools/genimage_rootless.cfg ; then
  sed -i s/'\t\t\t"usb.disk0",'/'\t\t\t"usb.disk0",\n\t\t\t"usb.mouse",'/g tools/common/sd_tools/genimage_rootless.cfg
fi
if ! grep -q "usb.keyboard" tools/common/sd_tools/genimage_rootless.cfg ; then
  sed -i s/'\t\t\t"usb.disk0",'/'\t\t\t"usb.disk0",\n\t\t\t"usb.keyboard",'/g tools/common/sd_tools/genimage_rootless.cfg
fi
#if ! grep -q "usb.hid" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
#  sed -i 's| \${output_dir}/input/usb.disk0$| ${output_dir}/input/usb.disk0\ntouch ${output_dir}/input/usb.hid|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
#fi
if ! grep -q "usb.touchpad" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
  sed -i 's| \${output_dir}/input/usb.disk0$| ${output_dir}/input/usb.disk0\ntouch ${output_dir}/input/usb.touchpad|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
fi
if ! grep -q "usb.mouse" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
  sed -i 's| \${output_dir}/input/usb.disk0$| ${output_dir}/input/usb.disk0\ntouch ${output_dir}/input/usb.mouse|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
fi
if ! grep -q "usb.keyboard" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
  sed -i 's| \${output_dir}/input/usb.disk0$| ${output_dir}/input/usb.disk0\ntouch ${output_dir}/input/usb.keyboard|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
fi
# set hostname prefix
if ! grep -q "hostname.prefix" tools/common/sd_tools/genimage_rootless.cfg ; then
  sed -i s/'\t\t\t"usb.touchpad",'/'\t\t\t"usb.touchpad",\n\t\t\t"hostname.prefix",'/g tools/common/sd_tools/genimage_rootless.cfg
fi
if ! grep -q "hostname.prefix" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
  sed -i 's| \${output_dir}/input/usb.touchpad$| ${output_dir}/input/usb.touchpad\necho -n kvm > ${output_dir}/input/hostname.prefix|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
fi
cd ..

BR_OUTPUT_DIR=output

source build/cvisetup.sh
defconfig ${SG_BOARD_LINK}

cd buildroot
if git checkout -b build ; then
  rm -f board/cvitek/SG200X/overlay/etc/init.d/uvc-gadget-server.elf
  rm -f board/cvitek/SG200X/overlay/etc/init.d/uvc-gadget-server.tar.xz
  git add board/cvitek/SG200X/overlay/etc/init.d
  git commit -m "build"
elif git branch -D build-nanokvm ; then
  true
fi
if [ -e ${BR_OUTPUT_DIR}/per-package/nanokvm-sg200x/target/kvmapp/system/init.d ]; then
  rsync -r --verbose --copy-dirlinks --copy-links --hard-links ${BR_OUTPUT_DIR}/per-package/nanokvm-sg200x/target/kvmapp/system/init.d/ board/cvitek/SG200X/overlay/etc/init.d/
  rm -f board/cvitek/SG200X/overlay/etc/init.d/S*kvm*
  rm -f board/cvitek/SG200X/overlay/etc/init.d/S*tailscale*
fi

if [ $maixcdk = y ]; then
  sed -i s/'^BR2_PACKAGE_PARTED=y'/'BR2_PACKAGE_MAIX_CDK=y\nBR2_PACKAGE_PARTED=y'/g configs/${BR_DEFCONFIG}
fi
if [ $nanokvm = y ]; then
  sed -i s/'^BR2_PACKAGE_PARTED=y'/'BR2_PACKAGE_NANOKVM_SG200X=y\nBR2_PACKAGE_PARTED=y'/g configs/${BR_DEFCONFIG}
fi
if [ $tailscale = y ]; then
  sed -i s/'^BR2_PACKAGE_PARTED=y'/'BR2_PACKAGE_TAILSCALE_RISCV64=y\nBR2_PACKAGE_PARTED=y'/g configs/${BR_DEFCONFIG}
fi
if [ $tpudemo = y ]; then
  sed -i s/'^# BR2_PACKAGE_TPUDEMO_SG200X is not set'/'BR2_PACKAGE_TPUDEMO_SG200X=y'/g configs/${BR_DEFCONFIG}
elif [ $tpudemo = n ]; then
  sed -i s/'^BR2_PACKAGE_TPUDEMO_SG200X=y'/'# BR2_PACKAGE_TPUDEMO_SG200X is not set'/g configs/${BR_DEFCONFIG}
fi
if [ $tpusdk = y ]; then
  sed -i s/'^# BR2_PACKAGE_SOPHGO_LIBRARY is not set'/'BR2_PACKAGE_SOPHGO_LIBRARY=y'/g configs/${BR_DEFCONFIG}
elif [ $tpusdk = n ]; then
  sed -i s/'^BR2_PACKAGE_SOPHGO_LIBRARY=y'/'# BR2_PACKAGE_SOPHGO_LIBRARY is not set'/g configs/${BR_DEFCONFIG}
fi

if git checkout -b build-nanokvm ; then
  git add board/cvitek/SG200X/overlay/etc/init.d
  git add configs/${BR_DEFCONFIG}
  git commit -m "build-nanokvm"
fi
cd ..

if [ -e cviruntime -a -e flatbuffers ]; then
  # small fix to keep fork of flatbuffers repository optional
  sed -i s/'-Werror=unused-parameter"'/'-Werror=unused-parameter -Wno-class-memaccess"'/g flatbuffers/CMakeLists.txt
  [ $tpusdk = y ] && export TPU_REL=1
fi

build_all

cd build
git restore boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/memmap.py
git restore boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
git restore tools/common/sd_tools/genimage_rootless.cfg
git restore tools/common/sd_tools/sd_gen_burn_image_rootless.sh
cd ..

installdir=`pwd`/install/soc_${SG_BOARD_LINK}
cd buildroot
cd ${BR_OUTPUT_DIR}/target
if [ -e kvmapp/server/NanoKVM-Server ]; then
  rm -f ${installdir}/nanokvm-latest.zip
  ln -s kvmapp latest
  zip -r --symlinks ${installdir}/nanokvm-latest.zip latest/*
  rm latest
fi
cd -
if git checkout build ; then
  true
fi
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*kvm*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*tailscale*
git restore board/cvitek/SG200X/overlay/etc/init.d
git restore configs/${BR_DEFCONFIG}
rm -f ${BR_OUTPUT_DIR}/target/etc/tailscale_disabled
rm -f ${BR_OUTPUT_DIR}/target/etc/init.d/S*kvm*
rm -f ${BR_OUTPUT_DIR}/target/etc/init.d/S*tailscale*
rm -f ${BR_OUTPUT_DIR}/target/usr/bin/tailscale
rm -f ${BR_OUTPUT_DIR}/target/usr/sbin/tailscaled
rm -rf ${BR_OUTPUT_DIR}/target/kvmapp/
cd ..

echo OK
