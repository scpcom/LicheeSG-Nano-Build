#!/bin/bash -e

cd build
# enable usb disk, disable ncm
sed -i s/'usb.ncm'/'usb.disk0'/g tools/common/sd_tools/genimage_rootless.cfg
sed -i 's|touch ${output_dir}/input/usb.ncm|echo /dev/mmcblk0p3 > ${output_dir}/input/usb.disk0|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
# enable usb hid
if ! grep -q "usb.hid" tools/common/sd_tools/genimage_rootless.cfg ; then
  sed -i s/'\t\t\t"usb.disk0",'/'\t\t\t"usb.disk0",\n\t\t\t"usb.hid",'/g tools/common/sd_tools/genimage_rootless.cfg
fi
if ! grep -q "usb.hid" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
  sed -i 's| \${output_dir}/input/usb.disk0$| ${output_dir}/input/usb.disk0\ntouch ${output_dir}/input/usb.hid|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
fi
# set hostname prefix
if ! grep -q "hostname.prefix" tools/common/sd_tools/genimage_rootless.cfg ; then
  sed -i s/'\t\t\t"usb.hid",'/'\t\t\t"usb.hid",\n\t\t\t"hostname.prefix",'/g tools/common/sd_tools/genimage_rootless.cfg
fi
if ! grep -q "hostname.prefix" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
  sed -i 's| \${output_dir}/input/usb.hid$| ${output_dir}/input/usb.hid\necho -n kvm > ${output_dir}/input/hostname.prefix|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
fi
cd ..

cd buildroot
# enable nanokvm app, disable tpudemo
sed -i s/'^BR2_PACKAGE_TPUDEMO_SG200X=y'/'BR2_PACKAGE_MAIX_CDK=y\nBR2_PACKAGE_NANOKVM_SG200X=y\nBR2_PACKAGE_TAILSCALE_RISCV64=y'/g configs/cvitek_SG200X_musl_riscv64_defconfig
cd ..

source build/cvisetup.sh
defconfig sg2002_licheervnano_sd
build_all

cd build
git restore tools/common/sd_tools/genimage_rootless.cfg
git restore tools/common/sd_tools/sd_gen_burn_image_rootless.sh
cd ..

cd buildroot
git restore configs/cvitek_SG200X_musl_riscv64_defconfig
cd ..

echo OK
