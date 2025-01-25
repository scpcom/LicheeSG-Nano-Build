#!/bin/bash
for s in host-tools/gcc/riscv64-linux-x86_64/sysroot/lib64*/lp* ; do
  t=`echo $s | sed 's|/sysroot/lib|/sysroot/usr/lib|g'`
  for f in $s/*.so* ; do
    d=`dirname $f`
    b=`basename $f`
    if [ ! -e $t/$b ]; then
      rsync -avpPxH $f $t/
    fi
  done
  for f in $t/*.so ; do
    l=`readlink $f`
    if [ "X$l" != "X" ]; then
      e=`dirname $l`
      c=`basename $l`
      if [ $l != $c -a -e $t/$c ]; then
        rm -f $f
        ln -s $c $f
      fi
    fi
  done
done
