#!/bin/bash
# pushd pacfix
#   cp parser.c.i.c parser.c
# popd
# rm -rf runtime
# mkdir -p runtime/afl-in
# mkdir runtime/afl-out

# /home/yuntong/pacfix/main.exe -debug -lvfile ./live_variables -cycle 600 -timeout 21600 -mode m ./config > runtime/pacfix.log 2>&1

# mv runtime runtime-moo

pushd pacfix
  cp parser.c.i.c parser.c
popd
rm -rf runtime
rm -rf runtime-dafl
mkdir -p runtime/afl-in
mkdir runtime/afl-out

/home/yuntong/pacfix/main.exe -debug -lvfile ./live_variables -cycle 600 -timeout 21600 -mode d ./config > runtime/pacfix.log 2>&1

mv runtime runtime-dafl


