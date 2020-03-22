#!/bin/sh -eu

# Compiler Flags
################
export CC=clang
export CXX=clang++

export CFLAGS='-Oz -march=broadwell -fno-asynchronous-unwind-tables -fno-strict-aliasing'
export CXXFLAGS='-Oz -march=broadwell'
export LDFLAGS='-fuse-ld=lld -w -s'


# Bootstrap Libraries
#####################
samu -C musl "$@"
samu -C zlib "$@"
samu -C netbsd-curses "$@"


# Bootstrap
#####################
samu -C toybox "$@"
samu -C dash "$@"
samu -C awk "$@"
samu -C byacc "$@"
samu -C gettext-tiny "$@"
samu -C samurai "$@"
samu -C make "$@"
samu -C python "$@"


#These have non Musl dependencies so we statically link them when bootstrapping
###############################################################################

CONFIGURE_OPTS='--disable-shared' MAKE_OPTS='curl_LDFLAGS=-all-static' samu -C curl "$@"
LDFLAGS="$LDFLAGS -static" samu -C less "$@"
LDFLAGS="$LDFLAGS -static" samu -C git "$@"
LDFLAGS="$LDFLAGS -static" samu -C cmake "$@"
