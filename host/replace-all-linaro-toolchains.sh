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

tcset=gcc-linaro-${gcver}-${tcdat}-${harch}

cd $d
for gctgt in $gctgts ; do
  gctar=gcc-linaro-${gcver}-${tcdat}-${harch}_${gctgt}.tar.xz
  srtar=none
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
  if [ -e ${tcset}.sha256 ]; then
    gcsum=`sha256sum ${gctar} | cut -d ' ' -f 1`
    if [ "X${gcsum}" = "X" ] ; then
      echo "failed to get sha256 for ${gctar}"
    elif grep -q '^'${gcsum}' .*'${gctar}'$' ${tcset}.sha256 ; then
      echo "${gcsum} ${gctar} OK"
    else
      echo "${gcsum} ${gctar} WRONG CHECKSUM"
      exit 1
    fi
  else
    echo "no sha256 file for ${gctar}"
  fi
  if [ -e ${tcset}.sha256 -a "${srtar}" != "none" ]; then
    srsum=`sha256sum ${srtar} | cut -d ' ' -f 1`
    if [ "X${srsum}" = "X" ] ; then
      echo "failed to get sha256 for ${srtar}"
    elif grep -q '^'${srsum}' .*'${srtar}'$' ${tcset}.sha256 ; then
      echo "${srsum} ${srtar} OK"
    else
      echo "${srsum} ${srtar} WRONG CHECKSUM"
      exit 1
    fi
  elif [ "${srtar}" != "none" ]; then
    echo "no sha256 file for ${srtar}"
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
