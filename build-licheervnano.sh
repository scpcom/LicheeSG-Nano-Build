#!/bin/bash -e

export SG_BOARD_FAMILY=sg200x
export SG_BOARD_LINK=sg2002_licheervnano_sd

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

source build/cvisetup.sh
defconfig ${SG_BOARD_LINK}

if [ -e cviruntime -a -e flatbuffers ]; then
  # small fix to keep fork of flatbuffers repository optional
  sed -i s/'-Werror=unused-parameter"'/'-Werror=unused-parameter -Wno-class-memaccess"'/g flatbuffers/CMakeLists.txt
  export TPU_REL=1
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

echo OK
