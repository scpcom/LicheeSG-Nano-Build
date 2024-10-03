#!/bin/bash -e

if git -C linux_5.10 checkout -b build 2>/dev/null ; then
  ln -sf ../../../../build/output/sg2002_licheervnano_sd/cvi_board_memmap.h linux_5.10/scripts/dtc/include-prefixes/cvi_board_memmap.h
  git -C linux_5.10 add scripts/dtc/include-prefixes/cvi_board_memmap.h
  d=`pwd`/build/boards/sg200x/sg2002_licheervnano_sd/dts_riscv
  for f in $d/*.dts ; do
    b=`basename $f`
    ln -sf $d/$b linux_5.10/arch/riscv/boot/dts/cvitek/$b
    git -C linux_5.10 add arch/riscv/boot/dts/cvitek/$b
  done
  d=`pwd`/build/boards/default/dts/sg200x
  for f in $d/*.dtsi ; do
    b=`basename $f`
    ln -sf $d/$b linux_5.10/arch/riscv/boot/dts/cvitek/$b
    git -C linux_5.10 add arch/riscv/boot/dts/cvitek/$b
  done
  git -C linux_5.10 commit -m "licheervnano: symlink dts and memmap"
fi

KERNEL_PATH=linux_5.10
KERNEL_TAG=`git -C ${KERNEL_PATH} describe --exact-match --tags HEAD 2>/dev/null || true`
[ "X$KERNEL_TAG" = "X" ] && git -C ${KERNEL_PATH} tag `date +%Y%m%d`
sed -i s/'describe --exact-match HEAD'/'describe --exact-match --tags HEAD'/g build/Makefile

echo OK
