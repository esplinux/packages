#!/bin/sh -eu

./clean.sh

espbuild -D BOOTSTRAP linuxHeaders.esp cacert.esp musl.esp curses.esp zlib.esp bearssl.esp dash.esp awk.esp byacc.esp less.esp make.esp curl.esp toybox.esp

mkdir sysroot

#tar -C sysroot -xf musl-*.tgz
tar -C sysroot -xf cacert-*.tgz
tar -C sysroot -xf toybox-*.tgz
tar -C sysroot -xf awk-*.tgz
#tar -C sysroot -xf byacc-*.tgz
tar -C sysroot -xf dash-*.tgz
#tar -C sysroot -xf less-*.tgz
#tar -C sysroot -xf make-*.tgz
tar -C sysroot -xf curl-*.tgz

cd sysroot
tar -czf ../sysroot.tgz *
cd ..

buildah bud -t esplinux/bootstrap .
