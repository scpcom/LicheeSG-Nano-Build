#!/bin/bash -e
d=`dirname $0`
cd $d ; d=`pwd` ; cd - > /dev/null

# Before running this script choose one of the options:
# 1. Build the toolchains
# ./host/build-all-thead-toolchains.sh
# 2. Provide a download url
# ./host/replace-all-thead-toolchains.sh https://some.example/path/to/toolchain
# 3. Download or copy the archives to the host folder
tcurl=$1

tcver=2.6.1
tcdat=20230307

harch=`uname -m`

gcver=10.2.0
gctgts="riscv64-linux
riscv64-linux-musl
riscv64-elf"

cd $d
for gctgt in $gctgts ; do
  gctar=${gctgt}-gcc-thead_${tcdat}-${gcver}-${harch}.tar.gz
  if [ ! -e ${gctar} ]; then
    wget -N ${tcurl}/${gctar}
  fi
done
cd ..

cd host-tools/
rm -rf gcc/
mkdir gcc
cd gcc
for gctgt in $gctgts ; do
  gctar=${gctgt}-gcc-thead_${tcdat}-${gcver}-${harch}.tar.gz
  tar xzf ${d}/${gctar}
done
cd ../..

sed -i s/x86_64/${harch}/g build/envsetup_soc.sh
sed -i s/x86_64/${harch}/g middleware/Makefile.param

echo OK
