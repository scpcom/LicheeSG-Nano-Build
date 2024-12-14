#!/bin/bash -e

gitsub="cnpy
cvi_rtsp
cvibuilder
cvikernel
cvimath
cviruntime
flatbuffers
ive
tdl_sdk"

for sub in $gitsub ; do
  if [ ! -e $sub ]; then
    echo $sub

    if [ $sub = cnpy ]; then
      git submodule add -b tpu https://github.com/sophgo/$sub
    elif [ $sub = cvi_rtsp -o $sub = flatbuffers -o $sub = tdl_sdk -o $sub = ive ]; then
      git submodule add -b master https://github.com/sophgo/$sub
    else
      git submodule add https://github.com/sophgo/$sub
    fi

    git submodule init $sub
  fi
done

echo OK
