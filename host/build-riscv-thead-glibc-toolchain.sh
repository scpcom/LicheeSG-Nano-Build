#!/bin/bash -e
d=`dirname $0`
cd $d ; d=`pwd` ; cd - > /dev/null

lxver=5.10.4
tclib=glibc
tcver=2.6.1
#tcdat=20220906
tcdat=20230307

gctgt=riscv64-linux
gctup=riscv64-unknown-linux-gnu
gcver=10.2.0
gcrel=${gctgt}-`uname -m`
gctar=${gctgt}-gcc-thead_${tcdat}-${gcver}-`uname -m`.tar.gz

installpkgs(){
  echo "Updating repositories..."
  apt-get update

  echo "Installing required packages..."

  apt-get install -y libusb-1.0-0-dev
  apt-get install -y libhidapi-dev libftdi-dev libjaylink-dev
  apt-get install -y jimsh tclsh libjim-dev
  #apt-get build-dep openocd

  apt-get install -y autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev
}

isadmin=`whoami`
if [ "X$1" = "X--no-prepare" ]; then
  true
elif [ "X$1" = "X--prepare" ]; then
  installpkgs
  exit $?
elif [ "X$isadmin" = "Xroot" ]; then
  installpkgs
else
  sudo $0 --prepare
fi

cd $d

if [ ! -e toolchain ]; then
  #git clone -b master-csky-open-v0.7.1 https://github.com/c-sky/riscv-gnu-toolchain toolchain
  git clone -b xuantie-gnu-toolchain-v2.6.x https://github.com/scpcom/riscv-gnu-toolchain toolchain
  tar czf xuantie-gnu-toolchain-source.tar.gz toolchain
fi

cd toolchain

if [ -e ${gcrel} ]; then
  echo "${gcrel} already built"
  exit 0
fi

git submodule update --init --recursive
if [ ! -e riscv-musl ]; then
  git submodule add -b thead-sdk-v1.1.2 https://github.com/scpcom/riscv-musl.git riscv-musl
fi

export PREFIX=`pwd`/build

if [ ! -e $PREFIX ]; then
  echo "Cleanup..."
  rm -rf build*/
  rm -rf stamps/
  rm -f config.log
  rm -f config.status
fi
cd ..

if [ ! -e xuantie-gnu-toolchain-submodule-source.tar.gz ]; then
  echo "Packing sources..."
  tar czf xuantie-gnu-toolchain-submodule-source.tar.gz toolchain
fi

echo "Building..."
cd toolchain

if [ ! -e $PREFIX ]; then
  mkdir `pwd`/build
fi

./configure --target=${gctup} \
--with-pkgversion="Xuantie-900 linux-${lxver} ${tclib} gcc Toolchain V${tcver} B-${tcdat}" \
\
--prefix=`pwd`/build \
\
--with-system-zlib \
--enable-multilib --with-abi=lp64d --with-arch=rv64gcxthead --with-cmodel=medany \
'CFLAGS_FOR_TARGET=-O2 -mcmodel=medany' 'CXXFLAGS_FOR_TARGET=-O2 -mcmodel=medany'

if [ $tclib = musl ]; then
MUSL_TUPLE=${gctup} \
GCC_CXXFLAGS_EXTRA="-DTHEAD_VERSION_NUMBER=${tcver}" \
make musl
elif [ $tclib = elf ]; then
NEWLIB_TUPLE=${gctup} \
GCC_CXXFLAGS_EXTRA="-DTHEAD_VERSION_NUMBER=${tcver}" \
make newlib
else
LINUX_TUPLE=${gctup} \
GCC_CXXFLAGS_EXTRA="-DTHEAD_VERSION_NUMBER=${tcver}" \
make linux
fi

cd $PREFIX
set +e
# Strip unused symbols in toolchain binaries
for i in `find libexec bin -type f`; do strip -s $i ; done
cd ..

echo "Packing toolchain..."
mv build ${gcrel}

if [ $tclib = musl ]; then
  if [ -e riscv64-linux-x86_64/sysroot/usr/include/sys/queue.h -a \
     ! -e ${gcrel}/sysroot/usr/include/sys/queue.h ]; then
    cp -p riscv64-linux-x86_64/sysroot/usr/include/sys/queue.h ${gcrel}/sysroot/usr/include/sys/
  fi

  cd ${gcrel}

  for m in 64v0p7_xthead 64v_xthead 64xthead ; do
    if [ -e sysroot/usr/lib${m}/lp64/libc.so -a ! -e sysroot/lib/ld-musl-riscv${m}-sf.so.1 ]; then
      ln -s ../usr/lib${m}/lp64/libc.so sysroot/lib/ld-musl-riscv${m}-sf.so.1
    fi
    if [ -e sysroot/usr/lib${m}/lp64d/libc.so -a ! -e sysroot/lib/ld-musl-riscv${m}.so.1 ]; then
      ln -s ../usr/lib${m}/lp64d/libc.so sysroot/lib/ld-musl-riscv${m}.so.1
    fi
  done

  cd ..
fi

fakeroot tar czf ../${gctar} ${gcrel}
cd ..
echo ${gctar}
sha256sum ${gctar} | cut -d ' ' -f 1 | tr a-z A-Z
stat -c %s ${gctar}

echo OK
