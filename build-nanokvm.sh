#!/bin/bash -e

export SG_BOARD_FAMILY=sg200x
export SG_BOARD_LINK=sg2002_licheervnano_sd

maixcdk=n
tailscale=n
tpusdk=n
while [ "$#" -gt 0 ]; do
	case "$1" in
	--maix-cdk|--maixcdk)
		shift
		maixcdk=y
		;;
	--tailscale)
		shift
		tailscale=y
		;;
	--tpu-sdk|--tpusdk)
		shift
		tpusdk=y
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

if [ -e prepare-licheesgnano.sh ]; then
  bash -e prepare-licheesgnano.sh
fi

cd build
# Expand user space RAM from 128MB to 160MB
sed -i s/'ION_SIZE = .* . SIZE_1M'/'ION_SIZE = 75 * SIZE_1M'/g boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/memmap.py
sed -i s/'BOOTLOGO_SIZE = .* . SIZE_1K'/'BOOTLOGO_SIZE = 5632 * SIZE_1K'/g boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/memmap.py
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

cd buildroot
if git checkout -b build ; then
  rm -f board/cvitek/SG200X/overlay/etc/init.d/uvc-gadget-server.elf
  rm -f board/cvitek/SG200X/overlay/etc/init.d/uvc-gadget-server.tar.xz
  git add board/cvitek/SG200X/overlay/etc/init.d
  git commit -m "build"
elif git branch -D build-nanokvm ; then
  true
fi
if [ -e output/per-package/nanokvm-sg200x/target/kvmapp/system/init.d ]; then
  rsync -r --verbose --copy-dirlinks --copy-links --hard-links output/per-package/nanokvm-sg200x/target/kvmapp/system/init.d/ board/cvitek/SG200X/overlay/etc/init.d/
  rm -f board/cvitek/SG200X/overlay/etc/init.d/S*kvm*
  rm -f board/cvitek/SG200X/overlay/etc/init.d/S*tailscale*
fi

# enable nanokvm app, disable tpudemo
sed -i s/'^BR2_PACKAGE_TPUDEMO_SG200X=y'/'BR2_PACKAGE_NANOKVM_SG200X=y'/g configs/cvitek_SG200X_musl_riscv64_defconfig
if [ $maixcdk = y ]; then
  sed -i s/'^BR2_PACKAGE_NANOKVM_SG200X=y'/'BR2_PACKAGE_MAIX_CDK=y\nBR2_PACKAGE_NANOKVM_SG200X=y'/g configs/cvitek_SG200X_musl_riscv64_defconfig
fi
if [ $tailscale = y ]; then
  sed -i s/'^BR2_PACKAGE_NANOKVM_SG200X=y'/'BR2_PACKAGE_NANOKVM_SG200X=y\nBR2_PACKAGE_TAILSCALE_RISCV64=y'/g configs/cvitek_SG200X_musl_riscv64_defconfig
fi

if git checkout -b build-nanokvm ; then
  git add board/cvitek/SG200X/overlay/etc/init.d
  git add configs/cvitek_SG200X_musl_riscv64_defconfig
  git commit -m "build-nanokvm"
fi
cd ..

source build/cvisetup.sh
defconfig ${SG_BOARD_LINK}

if [ -e cviruntime -a -e flatbuffers ]; then
  # small fix to keep fork of flatbuffers repository optional
  sed -i s/'-Werror=unused-parameter"'/'-Werror=unused-parameter -Wno-class-memaccess"'/g flatbuffers/CMakeLists.txt
  [ $tpusdk = y ] && export TPU_REL=1
fi

build_all

cd build
git restore boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/memmap.py
git restore tools/common/sd_tools/genimage_rootless.cfg
git restore tools/common/sd_tools/sd_gen_burn_image_rootless.sh
cd ..

installdir=`pwd`/install/soc_${SG_BOARD_LINK}
cd buildroot
cd output/target
if [ -e kvmapp/server/NanoKVM-Server ]; then
  rm -f ${installdir}/nanokvm-latest.zip
  ln -s kvmapp latest
  zip -r --symlinks ${installdir}/nanokvm-latest.zip latest/*
  rm latest
fi
cd ../..
if git checkout build ; then
  true
fi
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*kvm*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*tailscale*
git restore board/cvitek/SG200X/overlay/etc/init.d
git restore configs/cvitek_SG200X_musl_riscv64_defconfig
rm -f output/target/etc/tailscale_disabled
rm -f output/target/etc/init.d/S*kvm*
rm -f output/target/etc/init.d/S*tailscale*
rm -f output/target/usr/bin/tailscale
rm -f output/target/usr/sbin/tailscaled
rm -rf output/target/kvmapp/
cd ..

echo OK
