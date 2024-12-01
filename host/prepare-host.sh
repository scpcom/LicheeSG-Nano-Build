#!/bin/bash -e

installpkgs(){
  echo "Updating repositories..."
  apt-get update

  echo "Installing required packages..."
  apt-get install -y build-essential cmake git pkg-config rsync unzip wget zip
  apt-get install -y bc bison flex libncurses-dev libssl-dev device-tree-compiler
  apt-get install -y dosfstools file mtools
  apt-get install -y fuse2fs shellcheck

  echo "Checking for python..."
  pythonbin=`which python || true`
  if [ "X${pythonbin}" = "X" ]; then
    if apt-get install -y python3 ; then
      apt-get install -y python-is-python3 || true
    fi
  fi
}

isadmin=`whoami`
if [ "X$1" = "Xinstallpkgs" ]; then
  installpkgs
  exit $?
elif [ "X$isadmin" = "Xroot" ]; then
  installpkgs
else
  sudo $0 installpkgs
fi

echo "Checking git config..."
gitusermail=`git config user.email || true`
gitusername=`git config user.name || true`
if [ "X${gitusermail}" = "X" ]; then
  echo "warning: please run git config to set user.email"
  git config --global user.email "builder@localhost.localdomain"
fi
if [ "X${gitusername}" = "X" ]; then
  echo "warning: please run git config to set user.name"
  git config --global user.name "builder"
fi

echo OK
