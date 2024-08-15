#!/usr/bin/env sh

set -eux

cd build
# enable rndis script on boot for licheervnano
git am ../patches/build/0006-boards-sg200x-sg2002_licheervnano_sd-enable-rndis-sc.patch

# disable rndis script, enable acm script 
git am ../patches/build/0015-boards-sg200x-sg2002_licheervnano_sd-sg2002_licheerv.patch

# licheervnano enable package lcd, initial lcd on bootup
git am ../patches/build/0019-boards-sg200x-sg2002_licheervnano_sd-sg2002_licheerv.patch

# licheervnano enable a lot of package, for debug usage
git am ../patches/build/0020-boards-sg200x-sg2002_licheervnano_sd-sg2002_licheerv.patch

# licheervnano enable tpu demo for tpu test
git am ../patches/build/0022-boards-sg200x-sg2002_licheervnano_sd-sg2002_licheerv.patch

# enable haveged unifont qt5 qt5demo
git am ../patches/build/0026-sg2002_licheervnano_sd_defconfig-enable-haveged-unif.patch

# licheervnano: enable libdaemon expat dbus avahi
git am ../patches/build/0028-sg2002_licheervnano_defconfig-enable-libdaemon-expat.patch

git am ../patches/build/0031-sg2002_licheervnano_sd_defconfig-clean-buggy-package.patch
git am ../patches/build/0033-sg2002_licheervnano_sd_defconfig-add-input-event-dae.patch
