#!/bin/bash

export AFLRUN=/home/yuntong/vulnfix/thirdparty/AFLRun
rm -rf aflrun_build && mkdir aflrun_build
pushd aflrun_build
  mkdir temp
  TMP_DIR=$PWD/temp
  mkdir aflrun_tmp
  export AFLRUN_TMP=$PWD/aflrun_tmp
  echo "elf64-x86-64.c:6632" > $TMP_DIR/BBtargets.txt
  export AFLRUN_BB_TARGETS=$TMP_DIR/BBtargets.txt
  export AFLRUN_TARGETS="objdump"
  # export ADDITIONAL_FLAGS="-flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0  ../source/configure --enable-static --disable-shared --without-threads --without-lzma
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0  make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" -j10
popd

cp ./aflrun_build/binutils/objdump ./objdump.aflrun
