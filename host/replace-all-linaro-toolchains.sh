#!/bin/bash -e
d=`dirname $0`
cd $d ; d=`pwd` ; cd - > /dev/null

tcurl=$1
[ "X${tcurl}" = "X" ] && tcurl=https://releases.linaro.org/components/toolchain/binaries

tcver=6.3
tcdat=2017.05

harch=`uname -m`

gcver=6.3.1
lcver=2.23
gctgts="arm-linux-gnueabihf
aarch64-linux-gnu
aarch64-elf"

cd $d
for gctgt in $gctgts ; do
  gctar=gcc-linaro-${gcver}-${tcdat}-${harch}_${gctgt}.tar.xz
  if [ ! -e ${gctar} ]; then
    wget -N ${tcurl}/${tcver}-${tcdat}/${gctgt}/${gctar}
  fi
  #rttar=runtime-gcc-linaro-${gcver}-${tcdat}-${gctgt}.tar.xz
  if echo ${gctgt} | grep -q linux ; then
    srtar=sysroot-glibc-linaro-${lcver}-${tcdat}-${gctgt}.tar.xz
    if [ ! -e ${srtar} ]; then
      wget -N ${tcurl}/${tcver}-${tcdat}/${gctgt}/${srtar}
    fi
  fi
done
cd ..

mkdir -p host-tools

cd host-tools/
rm -rf gcc/gcc-linaro-*/
mkdir -p gcc
cd gcc
for gctgt in $gctgts ; do
  gctar=gcc-linaro-${gcver}-${tcdat}-${harch}_${gctgt}.tar.xz
  tar xJf ${d}/${gctar}
done
cd ../..

mkdir -p ramdisk

cd ramdisk/
rm -rf sysroot/sysroot-*linaro-*
mkdir -p sysroot
cd sysroot
for gctgt in $gctgts ; do
  if echo ${gctgt} | grep -q linux ; then
    srtar=sysroot-glibc-linaro-${lcver}-${tcdat}-${gctgt}.tar.xz
    tar xJf ${d}/${srtar}
  fi
done
cd ../..

echo OK
