#!/bin/bash -e

export SG_BOARD_FAMILY=sg200x
export SG_BOARD_LINK=sg2002_licheea53nano_sd

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
cd ..

if [ -e cviruntime -a -e flatbuffers ]; then
  # small fix to keep fork of flatbuffers repository optional
  sed -i s/'-Werror=unused-parameter"'/'-Werror=unused-parameter -Wno-class-memaccess"'/g flatbuffers/CMakeLists.txt
  [ $tpusdk = y ] && export TPU_REL=1
fi

build_all

cd buildroot
git restore configs/${BR_DEFCONFIG}
cd ..

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

echo OK
