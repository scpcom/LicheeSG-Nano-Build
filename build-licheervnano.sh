#!/bin/bash -e

export SG_BOARD_FAMILY=sg200x
export SG_BOARD_LINK=sg2002_licheervnano_sd

sdkver=keep
maixcdk=n
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
cd ..

if [ -e cviruntime -a -e flatbuffers ]; then
  # small fix to keep fork of flatbuffers repository optional
  sed -i s/'-Werror=unused-parameter"'/'-Werror=unused-parameter -Wno-class-memaccess"'/g flatbuffers/CMakeLists.txt
  [ $tpusdk = y ] && export TPU_REL=1
fi

build_all

# build other variant
cp -p build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig bak.config

# 2.8inch
cat bak.config | sed -e 's/CONFIG_MIPI_PANEL_ZCT2133V1/CONFIG_MIPI_PANEL_ST7701_HD228001C31/g' > build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
defconfig ${SG_BOARD_LINK}
clean_uboot
clean_opensbi
clean_fsbl
build_fsbl
cp -v install/soc_${SG_BOARD_LINK}/fip.bin install/soc_${SG_BOARD_LINK}/hd228001c31.bin

# 3inch
cat bak.config | sed -e 's/CONFIG_MIPI_PANEL_ZCT2133V1/CONFIG_MIPI_PANEL_ST7701_D300FPC9307A/g' > build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
defconfig ${SG_BOARD_LINK}
clean_uboot
clean_opensbi
clean_fsbl
build_fsbl
cp -v install/soc_${SG_BOARD_LINK}/fip.bin install/soc_${SG_BOARD_LINK}/d300fpc9307a.bin

# 5inch
cat bak.config | sed -e 's/CONFIG_MIPI_PANEL_ZCT2133V1/CONFIG_MIPI_PANEL_ST7701_DXQ5D0019B480854/g' > build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
defconfig ${SG_BOARD_LINK}
clean_uboot
clean_opensbi
clean_fsbl
build_fsbl
cp -v install/soc_${SG_BOARD_LINK}/fip.bin install/soc_${SG_BOARD_LINK}/dxq5d0019b480854.bin

mv bak.config build/boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig

cd build
git restore boards/${SG_BOARD_FAMILY}/${SG_BOARD_LINK}/${SG_BOARD_LINK}_defconfig
git restore tools/common/sd_tools/genimage_rootless.cfg
git restore tools/common/sd_tools/sd_gen_burn_image_rootless.sh
cd ..

cd buildroot
git restore configs/${BR_DEFCONFIG}
cd ..

echo OK
