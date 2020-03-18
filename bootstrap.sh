#!/bin/sh -eu

ninja -C musl
LDFLAGS=-static ninja -C dash $@
LDFLAGS=-static ninja -C toybox $@
LDFLAGS=-static ninja -C make $@
LDFLAGS=-static ninja -C byacc $@
