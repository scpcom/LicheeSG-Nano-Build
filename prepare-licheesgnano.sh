#!/bin/bash -e

if git -C linux_5.10 checkout -b build 2>/dev/null ; then
  ln -sf ../../../../build/output/sg2002_licheervnano_sd/cvi_board_memmap.h linux_5.10/scripts/dtc/include-prefixes/cvi_board_memmap.h
  git -C linux_5.10 add scripts/dtc/include-prefixes/cvi_board_memmap.h
  for a in sg200x/sg2000_duo_sd sg200x/sg2002_duo_sd sg200x/sg2002_licheervnano_sd ; do
    d=`pwd`/build/boards/$a/dts_riscv
    for f in $d/*.dts ; do
      b=`basename $f`
      ln -sf $d/$b linux_5.10/arch/riscv/boot/dts/cvitek/$b
      git -C linux_5.10 add arch/riscv/boot/dts/cvitek/$b
    done
  done
  for a in sg200x/sg2002_licheea53nano_sd sg200x/sg2000_wevb_sd ; do
    d=`pwd`/build/boards/$a/dts_arm
    for f in $d/*.dts ; do
      b=`basename $f`
      ln -sf $d/$b linux_5.10/arch/arm/boot/dts/cvitek/$b
      git -C linux_5.10 add arch/arm/boot/dts/cvitek/$b
    done
  done
  d=`pwd`/build/boards/default/dts/sg200x
  for f in $d/*.dtsi ; do
    b=`basename $f`
    ln -sf $d/$b linux_5.10/arch/riscv/boot/dts/cvitek/$b
    git -C linux_5.10 add arch/riscv/boot/dts/cvitek/$b
    ln -sf $d/$b linux_5.10/arch/arm/boot/dts/cvitek/$b
    git -C linux_5.10 add arch/arm/boot/dts/cvitek/$b
  done
  git -C linux_5.10 commit -m "licheervnano: symlink dts and memmap"
fi

if git -C u-boot-2021.10 checkout -b build 2>/dev/null ; then
  d=`pwd`/build/boards/sg200x/sg2002_licheervnano_sd/u-boot
  ln -sf $d/cvi_board_init.c u-boot-2021.10/board/cvitek/cvi_board_init.c
  git -C u-boot-2021.10 add board/cvitek/cvi_board_init.c
  ln -sf $d/cvitek.h u-boot-2021.10/include/cvitek/cvitek.h
  git -C u-boot-2021.10 add include/cvitek/cvitek.h
  ln -sf ../../build/output/sg2002_licheervnano_sd/cvi_board_memmap.h u-boot-2021.10/include/cvi_board_memmap.h
  git -C u-boot-2021.10 add include/cvi_board_memmap.h
  git -C u-boot-2021.10 commit -m "licheervnano: symlink dts and memmap"
fi

KERNEL_PATH=linux_5.10
KERNEL_TAG=`git -C ${KERNEL_PATH} describe --exact-match --tags HEAD 2>/dev/null || true`
[ "X$KERNEL_TAG" = "X" ] && git -C ${KERNEL_PATH} tag `date +%Y%m%d`
sed -i s/'describe --exact-match HEAD'/'describe --exact-match --tags HEAD'/g build/Makefile

echo OK
