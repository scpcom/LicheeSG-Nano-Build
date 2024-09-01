#!/bin/bash -e

if [ -e prepare-licheesgnano.sh ]; then
  bash -e prepare-licheesgnano.sh
fi

source build/cvisetup.sh
defconfig sg2002_licheervnano_sd
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
