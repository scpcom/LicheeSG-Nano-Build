#!/bin/sh -e
[ "X$GIT_SOURCE_HOST" != "X" ] || GIT_SOURCE_HOST=github.com
[ "X$GIT_TARGET_HOST" != "X" ] || GIT_TARGET_HOST=$GIT_HOST
[ "X$GIT_SOURCE_USER" != "X" ] || GIT_SOURCE_USER=scpcom
[ "X$GIT_TARGET_USER" != "X" ] || GIT_TARGET_USER=$GIT_USER
[ "X$GIT_TARGET_USER" != "X" ] || GIT_TARGET_USER=$GIT_SOURCE_USER

if [ "X$GIT_TARGET_HOST" = "X" ]; then
  if [ "$GIT_TARGET_USER" = "$GIT_SOURCE_USER" ]; then
    echo "Please set GIT_HOST and/or GIT_USER."
    exit 1
  else
    GIT_TARGET_HOST=$GIT_SOURCE_HOST
  fi
fi

GIT_SOURCE_USER_URL=https://$GIT_SOURCE_HOST/$GIT_SOURCE_USER
GIT_TARGET_USER_URL=https://$GIT_TARGET_HOST/$GIT_TARGET_USER

for loop in $(seq 1 4) ; do

find -name .git | while read g ; do
  d=$(dirname $g)
  [ -e $d/.git ] || continue
  #echo "cd $d"
  cd $d
  if [ -e .git/index ]; then
    c=$(dirname $d)
    a=$(basename $d)
    u=$(git remote get-url origin)
    b=$(git branch | grep -v detached | tr -d ' *')
    echo "cd $c && git clone -b $b $u $a"
  fi
  cd - > /dev/null
  [ -e $d/.gitmodules ] || continue
  submodule_update=always # false
  cd $d
  cat .gitmodules | grep -E '\[submodule ".*"\]' | cut -d '"' -f 2 | while read m ; do
    #echo $m
    n=$(grep -E '\[submodule "'$m'"\]|path = ' .gitmodules | grep -A1 -E '\[submodule "'$m'"\]' | grep 'path = ' | cut -d '=' -f 2- | cut -d ' ' -f 2-)
    u=$(grep -E '\[submodule "'$m'"\]|url = ' .gitmodules | grep -A1 -E '\[submodule "'$m'"\]' | grep 'url = ' | cut -d '=' -f 2- | cut -d ' ' -f 2-)
    s=$u
    u=$(echo $u | sed 's|'$GIT_SOURCE_USER_URL'|'$GIT_TARGET_USER_URL'|g')
    u=$(echo $u | sed 's|'https://boringssl.googlesource.com'|'$GIT_TARGET_USER_URL'|g')
    u=$(echo $u | sed 's|'https://github.com/krb5'|'$GIT_TARGET_USER_URL'|g')
    u=$(echo $u | sed 's|'https://github.com/pyca/cryptography'|'$GIT_TARGET_USER_URL'/pyca-cryptography|g')
    u=$(echo $u | sed 's|'https://github.com/FreeRTOS'|'$GIT_TARGET_USER_URL'|g')
    b=$(grep -E '\[submodule ".*"\]|branch = ' .gitmodules | grep -A1 -E '\[submodule "'$m'"\]' | grep 'branch = ' | cut -d '=' -f 2- | cut -d ' ' -f 2-)
    if [ "X$b" = "X" ]; then
      echo "cd $d && git submodule set-url $n $u"
    else
      echo "cd $d && git submodule set-url $n $u # $b"
    fi
    if [ "$s" != "$u" ]; then
      submodule_update=true
      git submodule set-url $n $u
    fi
  done
  echo "cd $d && git submodule update --init --depth=1"
  if [ $submodule_update != false ]; then
    git submodule update --init --depth=1
  fi
  cd - > /dev/null
done

done

echo OK
