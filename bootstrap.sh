#!/bin/sh -eu

./clean.sh

espbuild -D BOOTSTRAP linuxHeaders.esp cacert.esp musl.esp compilerRT.esp libunwind.esp libcxx.esp dash.esp awk.esp make.esp curl.esp toybox.esp llvm.esp clang.esp lld.esp

mkdir sysroot

tar -C sysroot -xf musl-*.tgz
tar -C sysroot -xf cacert-*.tgz
tar -C sysroot -xf toybox-*.tgz
tar -C sysroot -xf awk-*.tgz
#tar -C sysroot -xf byacc-*.tgz
tar -C sysroot -xf dash-*.tgz
#tar -C sysroot -xf less-*.tgz
tar -C sysroot -xf make-*.tgz
tar -C sysroot -xf curl-*.tgz
tar -C sysroot -xf llvm-*.tgz
tar -C sysroot -xf clang-*.tgz
tar -C sysroot -xf lld-*.tgz
tar -C sysroot -xf compiler-rt-*.tgz
tar -C sysroot -xf libunwind-*.tgz
tar -C sysroot -xf libcxxabi-*.tgz
tar -C sysroot -xf libcxx-*.tgz

cd sysroot
tar -czf ../sysroot.tgz *
cd ..

buildah bud -t esplinux/bootstrap .
