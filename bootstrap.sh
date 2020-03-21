#!/bin/sh -eu

if ! type "samu" > /dev/null; then
  SAMU='ninja'
else
  SAMU='samu'
fi

$SAMU -C musl "$@"
LDFLAGS=-static "$SAMU" -C dash "$@"
LDFLAGS=-static "$SAMU" -C toybox "$@"
LDFLAGS=-static "$SAMU" -C make "$@"
LDFLAGS=-static "$SAMU" -C byacc "$@"
