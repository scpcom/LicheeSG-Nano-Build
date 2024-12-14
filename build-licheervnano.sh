#!/bin/bash -e

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
defconfig sg2002_licheervnano_sd

# small fixes to avoid forks of tpu related repositories at this moment
if [ -e cvi_rtsp ]; then
  sed -i s/'${RANLIB} LIVE555_DIR='/'${RANLIB} CHIP_ARCH=${CHIP_ARCH} LIVE555_DIR='/g cvi_rtsp/build.sh
  if ! grep -q "D__CV181X__" cvi_rtsp/Makefile.inc ; then
    sed -i 's/CFLAGS += -DARCH_$(CHIP_ARCH)/CFLAGS += -DARCH_$(CHIP_ARCH)\n\nifeq ("$(CHIP_ARCH)", "SG200X")\nCFLAGS += -D__CV181X__\nendif\nifeq ("$(CHIP_ARCH)", "CV181X")\nCFLAGS += -D__CV181X__\nendif\nifeq ("$(CHIP_ARCH)", "CV180X")\nCFLAGS += -D__CV180X__\nendif/g' cvi_rtsp/Makefile.inc
  fi
  sed -i 's|-I$(KERNEL_INC)$|-I$(KERNEL_INC) -I$(MW_DIR)/component/isp/common -I$(MW_DIR)/../osdrv/interdrv/include/common/uapi/linux|g' cvi_rtsp/Makefile.inc
  sed -i 's|-I$(MW_DIR)/sample/common -I$(MW_DIR)/include/isp|-I$(MW_DIR)/sample/common -I$(MW_DIR)/component/isp/common -I$(MW_DIR)/include/isp|g' cvi_rtsp/Makefile.inc
fi
if [ -e cviruntime -a -e flatbuffers ]; then
  sed -i s/'CHIP_ID="${CHIP_ARCH,,}"'/'CHIP_ID="${CHIP_ARCH,,}"\n[ $CHIP_ID = sg200x ] \&\& CHIP_ID=cv181x'/g cviruntime/build_tpu_sdk.sh
  sed -i s/'-Werror=unused-parameter"'/'-Werror=unused-parameter -Wno-class-memaccess"'/g flatbuffers/CMakeLists.txt
  export TPU_REL=1
fi
if [ -e tdl_sdk ]; then
  sed -i s/'${CROSS_COMPILE} SDK_VER='/'${CROSS_COMPILE} LIVE555_DIR=${MLIR_SDK_ROOT} SDK_VER='/g tdl_sdk/cmake/cvi_rtsp.cmake
  sed -i s/'elif .. "$CHIP_ARCH" == "CV181X" ..; then'/'elif [[ "$CHIP_ARCH" == "CV181X" ]] || [[ "$CHIP_ARCH" == "SG200X" ]]; then\n    CHIP_ARCH=CV181X'/g tdl_sdk/scripts/*sdk_release.sh
fi

build_all
# build other variant
cp -p build/boards/sg200x/sg2002_licheervnano_sd/sg2002_licheervnano_sd_defconfig bak.config

# 2.8inch
cat bak.config | sed -e 's/CONFIG_MIPI_PANEL_ZCT2133V1/CONFIG_MIPI_PANEL_ST7701_HD228001C31/g' > build/boards/sg200x/sg2002_licheervnano_sd/sg2002_licheervnano_sd_defconfig
defconfig sg2002_licheervnano_sd
clean_uboot
clean_opensbi
clean_fsbl
build_fsbl
cp -v install/soc_sg2002_licheervnano_sd/fip.bin install/soc_sg2002_licheervnano_sd/hd228001c31.bin

# 3inch
cat bak.config | sed -e 's/CONFIG_MIPI_PANEL_ZCT2133V1/CONFIG_MIPI_PANEL_ST7701_D300FPC9307A/g' > build/boards/sg200x/sg2002_licheervnano_sd/sg2002_licheervnano_sd_defconfig
defconfig sg2002_licheervnano_sd
clean_uboot
clean_opensbi
clean_fsbl
build_fsbl
cp -v install/soc_sg2002_licheervnano_sd/fip.bin install/soc_sg2002_licheervnano_sd/d300fpc9307a.bin

# 5inch
cat bak.config | sed -e 's/CONFIG_MIPI_PANEL_ZCT2133V1/CONFIG_MIPI_PANEL_ST7701_DXQ5D0019B480854/g' > build/boards/sg200x/sg2002_licheervnano_sd/sg2002_licheervnano_sd_defconfig
defconfig sg2002_licheervnano_sd
clean_uboot
clean_opensbi
clean_fsbl
build_fsbl
cp -v install/soc_sg2002_licheervnano_sd/fip.bin install/soc_sg2002_licheervnano_sd/dxq5d0019b480854.bin

mv bak.config build/boards/sg200x/sg2002_licheervnano_sd/sg2002_licheervnano_sd_defconfig

echo OK
