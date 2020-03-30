#!/bin/sh -e

if ! type "samu" > /dev/null; then
  SAMU=ninja
else
  SAMU=samu
fi 

# Compiler Flags
################
export CC=clang
export CXX=clang++

export CFLAGS='-Oz -march=broadwell -fno-asynchronous-unwind-tables -fno-strict-aliasing'
export CXXFLAGS='-Oz -march=broadwell'
export LDFLAGS='-rtlib=compiler-rt -fuse-ld=lld -z noexecstack -z relro -z now -w -s'

# Bootstrap Libraries
#####################
$SAMU -C musl "$@"
#$SAMU -C zlib "$@"
#$SAMU -C netbsd-curses "$@"


# Bootstrap
#####################
$SAMU -C ca-certificates "$@"
$SAMU -C toybox "$@"
$SAMU -C dash "$@"
$SAMU -C awk "$@"
#$SAMU -C byacc "$@"
#$SAMU -C gettext-tiny "$@"
$SAMU -C samurai "$@"
$SAMU -C make "$@"
#$SAMU -C python "$@"
$SAMU -C espbuild "$@"


#These have non Musl dependencies so we statically link them when bootstrapping
###############################################################################
#CONFIGURE_OPTS='--disable-shared' MAKE_OPTS='curl_LDFLAGS=-all-static' $SAMU -C curl "$@"

LDFLAGS="-fuse-ld=lld -z noexecstack -z relro -z now -w -s -static" $SAMU -C lld "$@"
LDFLAGS="-fuse-ld=lld -z noexecstack -z relro -z now -w -s -static" $SAMU -C clang "$@"
#LDFLAGS="$LDFLAGS -static" $SAMU -C llvm "$@"

#LDFLAGS="$LDFLAGS -static" $SAMU -C less "$@"
#LDFLAGS="$LDFLAGS -static" $SAMU -C git "$@"
#LDFLAGS="$LDFLAGS -static" $SAMU -C cmake "$@"

if [ -z $1 ]
then
  rm -rf sysroot
  mkdir sysroot
  find . -maxdepth 2 -name '*.tgz' | xargs -n 1 tar -xC sysroot -f
  cd sysroot/bin; ln -sf dash sh; cd ../..
  tar -cC sysroot -zf sysroot.tgz .
fi

