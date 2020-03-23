#!/bin/sh -eu

SAMU=samu

if ! type "samu" > /dev/null; then
  SAMU=ninja
fi 

# Compiler Flags
################
export CC=clang
export CXX=clang++

export CFLAGS='-Oz -march=broadwell -fno-asynchronous-unwind-tables -fno-strict-aliasing'
export CXXFLAGS='-Oz -march=broadwell'
export LDFLAGS='-fuse-ld=lld -w -s'


# Bootstrap Libraries
#####################
$SAMU -C musl "$@"
$SAMU -C zlib "$@"
$SAMU -C netbsd-curses "$@"


# Bootstrap
#####################
$SAMU -C toybox "$@"
$SAMU -C dash "$@"
$SAMU -C awk "$@"
$SAMU -C byacc "$@"
$SAMU -C gettext-tiny "$@"
$SAMU -C samurai "$@"
$SAMU -C make "$@"
$SAMU -C python "$@"


#These have non Musl dependencies so we statically link them when bootstrapping
###############################################################################

CONFIGURE_OPTS='--disable-shared' MAKE_OPTS='curl_LDFLAGS=-all-static' $SAMU -C curl "$@"
LDFLAGS="$LDFLAGS -static" $SAMU -C less "$@"
LDFLAGS="$LDFLAGS -static" $SAMU -C git "$@"
LDFLAGS="$LDFLAGS -static" $SAMU -C cmake "$@"
