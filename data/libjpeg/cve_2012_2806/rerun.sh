#!/bin/bash
pushd pacfix
  cp jdmarker.c.i.c jdmarker.c
popd
rm -rf runtime
mkdir -p runtime/afl-in
mkdir runtime/afl-out

/home/yuntong/pacfix/main.exe -debug -lvfile ./live_variables -cycle 600 -timeout 21600 ./config > runtime/pacfix.log 2>&1