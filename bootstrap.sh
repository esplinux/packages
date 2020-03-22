#!/bin/sh -eu

export CC=clang
export CXX=clang++

export CFLAGS='-Oz -march=broadwell -fno-asynchronous-unwind-tables -fno-strict-aliasing'
export CXXFLAGS='-Oz -march=broadwell'
export LDFLAGS='-fuse-ld=lld -w -s'

# Bootstrap Libraries
samu -C musl "$@"
samu -C zlib "$@"
samu -C netbsd-curses "$@"

samu -C toybox "$@"
samu -C dash "$@"
samu -C awk "$@"
samu -C byacc "$@"
samu -C gettext-tiny "$@"
samu -C samurai "$@"
samu -C make "$@"
samu -C python "$@"


#These have dependencies other than libc
########################################

# Cleanly depends upon bearssl and libz just manually deploy those
samu -C curl "$@"

# We use a different version of curses so statically link
LDFLAGS="$LDFLAGS -static" samu -C less "$@"

# C++ so statically link
LDFLAGS="$LDFLAGS -static" samu -C cmake "$@"
