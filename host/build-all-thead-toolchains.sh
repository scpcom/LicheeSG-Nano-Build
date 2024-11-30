#!/bin/bash -e
d=`dirname $0`
cd $d ; d=`pwd` ; cd - > /dev/null
$d/build-riscv-thead-glibc-toolchain.sh
$d/build-riscv-thead-musl-toolchain.sh --no-prepare
$d/build-riscv-thead-elf-toolchain.sh --no-prepare
