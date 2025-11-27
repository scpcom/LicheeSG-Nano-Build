#!/bin/bash -e

export SG_BOARD_FAMILY=sg200x
export SG_BOARD_LINK=sg2002_licheervnano_sd

sdkver=keep
maixcdk=n
maixpy=n
osstar=y
qt5=y
tailscale=n
tpudemo=c
tpusdk=y
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
		maixpy=n
		;;
	--maix-py|--maixpy)
		shift
		maixcdk=y
		maixpy=y
		;;
	--no-maix-py|--no-maixpy)
		shift
		maixpy=n
		;;
	--qt5)
		shift
		qt5=y
		;;
	--no-qt5)
		shift
		qt5=n
		;;
	--oss-tar|--osstar)
		shift
		osstar=y
		;;
	--no-oss-tar|--no-osstar)
		shift
		osstar=n
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
  . ./prepare-licheesgnano.sh
fi

cd build
# board config for maixcdk
if [ $maixcdk = y ]; then
  if ! grep -q "board" tools/common/sd_tools/genimage_rootless.cfg ; then
    sed -i s/'\t\t\t"usb.dev",'/'\t\t\t"usb.dev",\n\t\t\t"board",'/g tools/common/sd_tools/genimage_rootless.cfg
  fi
  if ! grep -q "board" tools/common/sd_tools/sd_gen_burn_image_rootless.sh ; then
    sed -i 's| \${output_dir}/input/usb.dev$| ${output_dir}/input/usb.dev\necho "id=maixcam" > ${output_dir}/input/board\necho "name=MaixCAM" >> ${output_dir}/input/board\necho "panel=st7701_hd228001c31" >> ${output_dir}/input/board|g' tools/common/sd_tools/sd_gen_burn_image_rootless.sh
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
cd ..

source build/cvisetup.sh
defconfig ${SG_BOARD_LINK}

cd buildroot
if [ $maixcdk = y ]; then
  sed -i s/'^BR2_PACKAGE_PARTED=y'/'BR2_PACKAGE_MAIX_CDK=y\nBR2_PACKAGE_PARTED=y'/g configs/${BR_DEFCONFIG}
  sed -i s/'^BR2_PACKAGE_PARTED=y'/'BR2_PACKAGE_MAIXCAM_SG200X=y\nBR2_PACKAGE_PARTED=y'/g configs/${BR_DEFCONFIG}
fi
if [ $maixpy = y ]; then
  sed -i s/'^BR2_PACKAGE_PARTED=y'/'BR2_PACKAGE_MAIX_PY=y\nBR2_PACKAGE_PARTED=y'/g configs/${BR_DEFCONFIG}
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
if [ $qt5 = n ]; then
  sed -i /'BR2_PACKAGE_QT5'/d configs/${BR_DEFCONFIG}
fi
cd ..

if [ -e cvi_rtsp ]; then
  # fix "fatal error: Can't find suitable multilib set"
  sed -i s/'-march=rv64imafdcvxthead -mcmodel=medany -mabi=lp64dv'/'-march=rv64imafdcv0p7xthead -mcmodel=medany -mabi=lp64d'/g cvi_rtsp/Makefile.inc
fi
if [ -e cviruntime -a -e flatbuffers ]; then
  # small fix to keep fork of flatbuffers repository optional
  sed -i s/'-Werror=unused-parameter"'/'-Werror=unused-parameter -Wno-class-memaccess"'/g flatbuffers/CMakeLists.txt
  [ $tpusdk = y ] && export TPU_REL=1
fi
if [ $osstar = y ]; then
  export OSS_TARBALL_REL=1
fi

build_all

# build other variant
mkdir -p install/soc_${SG_BOARD_LINK}/configs
cp -p build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig bak.config
cp -v install/soc_${SG_BOARD_LINK}/fip.bin bak.fip
cp -v install/soc_${SG_BOARD_LINK}/fip_spl.bin bak.fip_spl

build_fip_variant() {
  panelconfig=`echo $1 | tr a-z A-Z`
  panelfip=`echo $1 | tr A-Z a-z | sed s/'^mipi_panel_'/''/g | sed s/'^st7701_'/''/g | sed s/'_60hz$'/''/g`
  cat bak.config | sed -e 's/CONFIG_MIPI_PANEL_ZCT2133V1/CONFIG_'${panelconfig}'/g' > build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
  grep -E '^CONFIG_MIPI_PANEL_.*=y' build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
  defconfig ${SG_BOARD_LINK}
  grep -E '^CONFIG_MIPI_PANEL_.*=y' build/.config
  clean_uboot
  clean_opensbi
  clean_fsbl
  build_fsbl
  cp -v install/soc_${SG_BOARD_LINK}/fip.bin install/soc_${SG_BOARD_LINK}/${panelfip}.bin
  cp -p build/.config install/soc_${SG_BOARD_LINK}/configs/${panelfip}-build-config
}

grep -E '^CONFIG_MIPI_PANEL_.*=y' build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig || true

if ! grep -q -E 'CONFIG_MIPI_PANEL_ZCT2133V1=y' bak.config ; then
  if grep -q -E '^CONFIG_MIPI_PANEL_.*=y' bak.config ; then
    sed -i s/'^CONFIG_MIPI_PANEL_.*=y'/'CONFIG_MIPI_PANEL_ZCT2133V1=y'/g bak.config
  else
    echo 'CONFIG_MIPI_PANEL_ZCT2133V1=y' >> bak.config
  fi
  build_fip_variant MIPI_PANEL_ZCT2133V1
fi
cp -v install/soc_${SG_BOARD_LINK}/fip.bin install/soc_${SG_BOARD_LINK}/zct2133v1.bin

# 7inch
build_fip_variant MIPI_PANEL_MTD700920B
# 2.8inch
build_fip_variant MIPI_PANEL_ST7701_HD228001C31
# 2.8inch alt0
build_fip_variant MIPI_PANEL_ST7701_HD228001C31_ALT0
# 2.28 inch lhcm
build_fip_variant MIPI_PANEL_ST7701_LHCM228TS003A
# 3inch
build_fip_variant MIPI_PANEL_ST7701_D300FPC9307A
# 3.1inch
build_fip_variant MIPI_PANEL_ST7701_D310T9362V1
# 5inch
build_fip_variant MIPI_PANEL_ST7701_DXQ5D0019B480854
# 5inch new
build_fip_variant MIPI_PANEL_ST7701_DXQ5D0019_V0
# 2.4inch
build_fip_variant MIPI_PANEL_D240SI31
# dsi to hdmi
build_fip_variant MIPI_PANEL_LT9611_1024X768_60HZ
# dsi to hdmi
build_fip_variant MIPI_PANEL_LT9611_1280X720_60HZ

if echo ${SG_BOARD_LINK} | grep -q milkv_duos ; then
  # 8inch
  build_fip_variant MIPI_PANEL_MILKV_8HD
  # 8inch 2lane
  build_fip_variant MIPI_PANEL_MILKV_8HD_2LANE
  # 4inch
  build_fip_variant MIPI_PANEL_MILKV_ST7796S
fi

mv bak.config build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
mv bak.fip install/soc_${SG_BOARD_LINK}/fip.bin
mv bak.fip_spl install/soc_${SG_BOARD_LINK}/fip_spl.bin

cd build
git restore boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
git restore tools/common/sd_tools/genimage_rootless.cfg
git restore tools/common/sd_tools/sd_gen_burn_image_rootless.sh
cd ..

installdir=`pwd`/install/soc_${SG_BOARD_LINK}
cd buildroot
cd ${BR_OUTPUT_DIR}/target
if [ -e maixapp/apps/app.info ]; then
  rm -f ${installdir}/maixcam-latest.zip
  zip -r --symlinks ${installdir}/maixcam-latest.zip \
    maixapp/* \
    usr/lib/python3*/*-packages/maix* \
    usr/lib/python3*/*-packages/Maix*
fi
cd -
git restore configs/${BR_DEFCONFIG}
cd ..

echo OK
