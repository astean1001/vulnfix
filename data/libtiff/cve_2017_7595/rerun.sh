#!/bin/bash
pushd pacfix/tools
  cp tiff2pdf.c.i.c tiff2pdf.c
popd
rm -rf runtime
mkdir -p runtime/afl-in
mkdir runtime/afl-out

/home/yuntong/pacfix/main.exe -debug -lvfile ./live_variables -cycle 600 -timeout 21600 ./config > runtime/pacfix.log 2>&1