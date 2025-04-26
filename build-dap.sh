#!/bin/bash -e

export SG_BOARD_FAMILY=sg200x
export SG_BOARD_LINK=sg2002_licheervnano_sd

sdkver=keep
maixcdk=n
dap=y
shrink=y
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
	--shrink)
		shift
		shrink=y
		;;
	--no-shrink)
		shift
		shrink=n
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

offcnf="CONFIG_IP_VS
CONFIG_WIREGUARD
CONFIG_PACKET_DIAG
CONFIG_UNIX_DIAG
CONFIG_NETLINK_DIAG
CONFIG_PACKET_DIAG
CONFIG_NET_IPGRE
CONFIG_VXLAN
CONFIG_USB_SERIAL
CONFIG_USB_ACM
CONFIG_VIDEO_CVITEK
CONFIG_FB_CVITEK
CONFIG_JFFS2_FS
CONFIG_SQUASHFS"

yescnf="CONFIG_FB_SIMPLE"

modcnf="CONFIG_STMMAC_PLATFORM
CONFIG_DWMAC_CVITEK"

for c in $offcnf ; do
  sed -i s/'^'$c'=.$'/'# '$c' is not set'/g boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/linux/*${SG_BOARD_LINK}_defconfig
done

echo >> boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/linux/*${SG_BOARD_LINK}_defconfig

for c in $yescnf ; do
  if ! grep -q '^'$c'=y' boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/linux/*${SG_BOARD_LINK}_defconfig ; then
    echo $c'=y' >> boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/linux/*${SG_BOARD_LINK}_defconfig
  fi
done

for c in $modcnf ; do
  if ! grep -q '^'$c'=m' boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/linux/*${SG_BOARD_LINK}_defconfig ; then
    echo $c'=m' >> boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/linux/*${SG_BOARD_LINK}_defconfig
  fi
done

offubt="BMP
VIDCONSOLE
CVI_VO
DISPLAY
LOGO
VIDEO"

for c in $offubt ; do
  sed -i /$c/d boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/u-boot/*${SG_BOARD_LINK}_defconfig
done

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

# disable gt9xx
sed -i /gt9xx/d tools/common/sd_tools/genimage_rootless.cfg
sed -i /gt9xx/d tools/common/sd_tools/sd_gen_burn_image_rootless.sh
# remove logo
sed -i /logo.jpeg/d tools/common/sd_tools/genimage_rootless.cfg
# copy logo is required for partition layout
#sed -i /logo.jpeg/d tools/common/sd_tools/sd_gen_burn_image_rootless.sh
# disable ncm
sed -i /usb.ncm/d tools/common/sd_tools/genimage_rootless.cfg
sed -i /usb.ncm/d tools/common/sd_tools/sd_gen_burn_image_rootless.sh
# enable wifi.ap
sed -i s/wifi.sta/wifi.ap/g tools/common/sd_tools/genimage_rootless.cfg
sed -i s/wifi.sta/wifi.ap/g tools/common/sd_tools/sd_gen_burn_image_rootless.sh
# enable wifi.only
sed -i s/'\t\t\t"usb.dev",'/'\t\t\t"usb.dev",\n\t\t\t"wifi.only",'/g tools/common/sd_tools/genimage_rootless.cfg
sed -i 's| \${output_dir}/input/usb.dev$| ${output_dir}/input/usb.dev\ntouch ${output_dir}/input/wifi.only|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh

# set hostname prefix
if ! grep -q "hostname.prefix" tools/common/sd_tools/genimage_rootless.cfg ; then
  sed -i s/'\t\t\t"usb.dev",'/'\t\t\t"hostname.prefix",\n\t\t\t"usb.dev",'/g tools/common/sd_tools/genimage_rootless.cfg
fi
if ! grep -q "hostname.prefix" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
  sed -i 's|^touch \${output_dir}/input/usb.dev$|echo -n dap > ${output_dir}/input/hostname.prefix\ntouch \${output_dir}/input/usb.dev|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
fi

# disable rndis
sed -i /usb.rndis/d tools/common/sd_tools/genimage_rootless.cfg
sed -i /usb.rndis/d tools/common/sd_tools/sd_gen_burn_image_rootless.sh
# enable usb.host
sed -i s/usb.dev/usb.host/g tools/common/sd_tools/genimage_rootless.cfg
sed -i s/usb.dev/usb.host/g tools/common/sd_tools/sd_gen_burn_image_rootless.sh
cd ..

cd ramdisk
sed -i s/'^sleep 0'/'#sleep 0'/g initramfs/*/init
cd ..

BR_OUTPUT_DIR=output

source build/cvisetup.sh
defconfig ${SG_BOARD_LINK}

cd buildroot
branchdap=false
if git checkout -b build ; then
  rm -f board/cvitek/SG200X/overlay/etc/init.d/uvc-gadget-server.elf
  rm -f board/cvitek/SG200X/overlay/etc/init.d/uvc-gadget-server.tar.xz
  git add board/cvitek/SG200X/overlay/etc/init.d
  git commit -m "build"
elif git branch -D build-dap ; then
  true
elif git checkout build-dap ; then
  branchdap=true
fi

modoff="soph_fast_image.ko
soph_fb.ko
soph_ive.ko
soph_jpeg.ko
soph_mipi_rx.ko
soph_mipi_tx.ko
soph_rgn.ko
soph_rtos_cmdqu.ko
soph_saradc.ko
soph_snsr_i2c.ko
soph_tpu.ko
soph_vc_driver.ko
soph_vcodec.ko
soph_vi.ko
soph_vo.ko
soph_vpss.ko"

for m in $modoff; do
  sed -i s/'insmod '$m/'#insmod '$m/g board/cvitek/SG200X/overlay/etc/init.d/S00kmod
done
#rm -f board/cvitek/SG200X/overlay/etc/init.d/S03usb*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S04backlight
rm -f board/cvitek/SG200X/overlay/etc/init.d/S04fb
rm -f board/cvitek/SG200X/overlay/etc/init.d/S05tp
#rm -f board/cvitek/SG200X/overlay/etc/init.d/S30eth
#rm -f board/cvitek/SG200X/overlay/etc/init.d/S30gadget_nic
rm -f board/cvitek/SG200X/overlay/etc/init.d/S99*test
rm -f board/cvitek/SG200X/overlay/etc/init.d/uvc_tool.sh

rm -f board/cvitek/SG200X/overlay/etc/init.d/S*kvm*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*ssdp*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*tailscale*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*usbhid*

rm -f ${BR_OUTPUT_DIR}/target/etc/init.d/S*
rm -f ${BR_OUTPUT_DIR}/target/etc/init.d/uvc*

cat <<\EOF > board/cvitek/SG200X/overlay/etc/init.d/S05ethmod
#!/bin/sh

if [ "$1" = "start" ]
then
	. /etc/profile
	printf "load eth kernel module: "
	cd /mnt/system/ko/
	insmod stmmac-platform.ko
	insmod dwmac-thead.ko
	insmod dwmac-cvitek.ko
	echo "OK"
	exit 0
fi
EOF
chmod ugo+rx board/cvitek/SG200X/overlay/etc/init.d/S05ethmod

cat <<\EOF > board/cvitek/SG200X/overlay/etc/init.d/S99setupdap
#!/bin/sh

wifi_only() {
	mkdir -p /etc/init.off
	if [ -e /device_key_legacy ]
	then
		mv /etc/init.d/S02devicekey /etc/init.off/
		mv /etc/init.d/S10uuid /etc/init.off/
	fi
	if [ ! -e /mnt/system/usb-host.sh ]
	then
		mv /etc/init.d/S03usbdev /etc/init.off/
	fi
	mv /etc/init.d/S05ethmod /etc/init.off/
	mv /etc/init.d/S30eth /etc/init.off/
	mv /etc/init.d/S30gadget_nic /etc/init.off/
}

if [ "$1" = "start" ]
then
	. /etc/profile
	printf "dap setup: "
	if [ -e /etc/init.d/S95mpd ]
	then
		mkdir -p /etc/init.off
		mv /etc/init.d/S95mpd /etc/init.d/S23mpd
		mv /etc/init.d/S99local /etc/init.d/S22local
		mv /etc/init.d/S50avahi-daemon /etc/init.d/S51avahi-daemon
		mv /etc/init.d/S99resizefs /etc/init.off/
		if [ -e /boot/wifi.only ]
		then
			wifi_only
		fi
	fi
	echo "OK"
	exit 0
elif [ "$1" = "wifi-only" ]
then
	wifi_only
fi
EOF
chmod ugo+rx board/cvitek/SG200X/overlay/etc/init.d/S99setupdap

sed -i s/'^acm'/'#acm'/g board/cvitek/SG200X/overlay/etc/inittab

if [ $maixcdk = y ]; then
  sed -i s/'^BR2_PACKAGE_PARTED=y'/'BR2_PACKAGE_MAIX_CDK=y\nBR2_PACKAGE_PARTED=y'/g configs/${BR_DEFCONFIG}
fi
if [ $maixcdk = y -a $shrink = y ]; then
  sed -i s/'^BR2_PACKAGE_MAIX_CDK=y'/'BR2_PACKAGE_MAIX_CDK=y\n# BR2_PACKAGE_MAIX_CDK_ALL_PROJECTS is not set'/g configs/${BR_DEFCONFIG}
  sed -i s/'^BR2_PACKAGE_MAIX_CDK=y'/'BR2_PACKAGE_MAIX_CDK=y\n# BR2_PACKAGE_MAIX_CDK_ALL_EXAMPLES is not set'/g configs/${BR_DEFCONFIG}
fi
if [ $dap = y ]; then
  sed -i s/'^BR2_PACKAGE_PARTED=y'/'BR2_PACKAGE_MPD=y\nBR2_PACKAGE_PARTED=y'/g configs/${BR_DEFCONFIG}
  sed -i s/'^BR2_PACKAGE_MPD=y'/'BR2_PACKAGE_MPD=y\nBR2_PACKAGE_MPD_MPG123=y'/g configs/${BR_DEFCONFIG}
  sed -i s/'^BR2_PACKAGE_MPD=y'/'BR2_PACKAGE_MPD=y\nBR2_PACKAGE_MPD_FFMPEG=y'/g configs/${BR_DEFCONFIG}
  sed -i s/'^BR2_PACKAGE_MPD=y'/'BR2_PACKAGE_MPD=y\nBR2_PACKAGE_MPD_AVAHI_SUPPORT=y'/g configs/${BR_DEFCONFIG}
  sed -i s/'^BR2_PACKAGE_PARTED=y'/'BR2_PACKAGE_SHAIRPORT_SYNC=y\nBR2_PACKAGE_PARTED=y'/g configs/${BR_DEFCONFIG}
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
if [ $shrink = y ]; then
  sed -i /'^BR2_PACKAGE_PYTHON_'/d configs/${BR_DEFCONFIG}

  sed -i s/'^BR2_PACKAGE_PYTHON3_PY_PYC=y$'/'BR2_PACKAGE_PYTHON3_PY_PYC=y'\
'\nBR2_PACKAGE_PYTHON_REQUESTS=y'\
'\nBR2_PACKAGE_PYTHON_REQUESTS_OAUTHLIB=y'\
'\nBR2_PACKAGE_PYTHON_REQUESTS_TOOLBELT=y'/g configs/${BR_DEFCONFIG}

  sed -i /'^BR2_PACKAGE_GDB'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_HOST_GDB'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_GDB_'/d configs/${BR_DEFCONFIG}

  sed -i /'^BR2_PACKAGE_AIRCRACK'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_MOSH'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_LRZSZ'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_DHRYSTONE'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_COREMARK'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_RAMSPEED'/d configs/${BR_DEFCONFIG}
  #sed -i /'^BR2_PACKAGE_ALSA_UTILS'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_SQUASHFS'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_LCDTEST'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_ASCII_INVADERS'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_GNUCHESS'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_SL'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_XORCURSES'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_STRESS'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_EXPECT'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_TCL'/d configs/${BR_DEFCONFIG}

  sed -i s/'BR2_PACKAGE_OPENCV4_BUILD_TESTS=y'/'# BR2_PACKAGE_OPENCV4_BUILD_TESTS is not set'/g configs/${BR_DEFCONFIG}
  sed -i s/'BR2_PACKAGE_OPENCV4_BUILD_PERF_TESTS=y'/'# BR2_PACKAGE_OPENCV4_BUILD_PERF_TESTS is not set'/g configs/${BR_DEFCONFIG}

  #sed -i /'BR2_PACKAGE_FFMPEG'/d configs/${BR_DEFCONFIG}
  #sed -i /'BR2_PACKAGE_MPG123'/d configs/${BR_DEFCONFIG}
  sed -i /'BR2_PACKAGE_OPENCV'/d configs/${BR_DEFCONFIG}
fi
if [ $dap = y -a $shrink = y ]; then
  sed -i /'BR2_PACKAGE_BLUEZ'/d configs/${BR_DEFCONFIG}
  sed -i /'BR2_PACKAGE_LLDPD'/d configs/${BR_DEFCONFIG}
  sed -i /'BR2_PACKAGE_SSDP_RESPONDER'/d configs/${BR_DEFCONFIG}
  sed -i /'BR2_PACKAGE_UVC_GADGET'/d configs/${BR_DEFCONFIG}
fi
if [ $maixcdk = n -a $shrink = y ]; then
  #sed -i /'^BR2_PACKAGE_FFMPEG'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_LIBQRENCODE'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_LIBWEBSOCKETS'/d configs/${BR_DEFCONFIG}
  #sed -i /'^BR2_PACKAGE_MPG123'/d configs/${BR_DEFCONFIG}
  sed -i /'^BR2_PACKAGE_OPENCV'/d configs/${BR_DEFCONFIG}
fi

if git checkout -b build-dap ; then
  branchdap=true
fi
if [ $branchdap = true ]; then
  git add board/cvitek/SG200X/overlay/etc/init.d
  git add board/cvitek/SG200X/overlay/etc/inittab
  git add configs/${BR_DEFCONFIG}
  git commit -m "build-dap"
fi
cd ..

if [ -e cviruntime -a -e flatbuffers ]; then
  # small fix to keep fork of flatbuffers repository optional
  sed -i s/'-Werror=unused-parameter"'/'-Werror=unused-parameter -Wno-class-memaccess"'/g flatbuffers/CMakeLists.txt
  [ $tpusdk = y ] && export TPU_REL=1
fi

build_all

# build other variant
cp -p build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/u-boot/*${SG_BOARD_LINK}_defconfig bak.u-boot-config
cp -v install/soc_${SG_BOARD_LINK}/fip.bin bak.fip
cp -v install/soc_${SG_BOARD_LINK}/fip_spl.bin bak.fip_spl

# wifi only
cat bak.u-boot-config | sed /ETH/d > build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/u-boot/*${SG_BOARD_LINK}_defconfig
echo '# CONFIG_NET is not set' >> build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/u-boot/*${SG_BOARD_LINK}_defconfig
grep -E '^CONFIG_.*ETH.*=y|CONFIG_.*NET.*=y' build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/u-boot/*${SG_BOARD_LINK}_defconfig || true
defconfig ${SG_BOARD_LINK}
clean_uboot
clean_opensbi
clean_fsbl
build_fsbl
cp -v install/soc_${SG_BOARD_LINK}/fip.bin install/soc_${SG_BOARD_LINK}/wifi-only.bin

mv bak.u-boot-config build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/u-boot/*${SG_BOARD_LINK}_defconfig
mv bak.fip install/soc_${SG_BOARD_LINK}/fip.bin
mv bak.fip_spl install/soc_${SG_BOARD_LINK}/fip_spl.bin

cd build
git restore boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/memmap.py
git restore boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
git restore boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/linux/*${SG_BOARD_LINK}_defconfig
git restore boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/u-boot/*${SG_BOARD_LINK}_defconfig
git restore tools/common/sd_tools/genimage_rootless.cfg
git restore tools/common/sd_tools/sd_gen_burn_image_rootless.sh
cd ..

cd ramdisk
git restore initramfs/*/init
cd ..

installdir=`pwd`/install/soc_${SG_BOARD_LINK}
cd buildroot
cd ${BR_OUTPUT_DIR}/target
cd -
if git checkout build ; then
  true
fi
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*avahi*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*dnsmasq*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*kvm*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*ssdp*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*ssh*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S*tailscale*
rm -f board/cvitek/SG200X/overlay/etc/init.d/S05ethmod
rm -f board/cvitek/SG200X/overlay/etc/init.d/S99setupdap
git restore board/cvitek/SG200X/overlay/etc/init.d
git restore board/cvitek/SG200X/overlay/etc/inittab
git restore configs/${BR_DEFCONFIG}
rm -f ${BR_OUTPUT_DIR}/target/etc/tailscale_disabled
rm -f ${BR_OUTPUT_DIR}/target/etc/init.d/S*kvm*
rm -f ${BR_OUTPUT_DIR}/target/etc/init.d/S*tailscale*
rm -f ${BR_OUTPUT_DIR}/target/usr/bin/tailscale
rm -f ${BR_OUTPUT_DIR}/target/usr/sbin/tailscaled
rm -rf ${BR_OUTPUT_DIR}/target/kvmapp/
cd ..

echo OK
