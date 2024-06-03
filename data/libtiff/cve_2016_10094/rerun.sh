#!/bin/bash
pushd pacfix/tools
  cp tiff2pdf.c.i.c tiff2pdf.c
popd
rm -rf runtime runtime-moo
mkdir -p runtime/afl-in
mkdir runtime/afl-out

/home/yuntong/pacfix/main.exe -debug -lvfile ./live_variables -cycle 600 -timeout 21600 -mode m ./config > runtime/pacfix.log 2>&1

mv runtime runtime-moo

pushd pacfix/tools
  cp tiff2pdf.c.i.c tiff2pdf.c
popd
rm -rf runtime-dafl
rm -rf runtime
mkdir -p runtime/afl-in
mkdir runtime/afl-out

/home/yuntong/pacfix/main.exe -debug -lvfile ./live_variables -cycle 600 -timeout 21600 -mode d ./config > runtime/pacfix.log 2>&1
mv runtime runtime-dafl
