#!/bin/bash

# rm -rf source
# git clone https://github.com/bminor/binutils-gdb.git
# mv binutils-gdb source
# cd source/
# git checkout 515f23e63c0074ab531bc954f84ca40c6281a724

export AFLRUN=/home/yuntong/vulnfix/thirdparty/AFLRun
rm -rf aflrun_build && mkdir aflrun_build
pushd aflrun_build
  mkdir temp
  TMP_DIR=$PWD/temp
  mkdir aflrun_tmp
  export AFLRUN_TMP=$PWD/aflrun_tmp
  echo "dwarf2.c:2441" > $TMP_DIR/BBtargets.txt
  export AFLRUN_BB_TARGETS=$TMP_DIR/BBtargets.txt
  export AFLRUN_TARGETS="nm-new"
  # export ADDITIONAL_FLAGS="-flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0  ../source/configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim LIBS='-ldl -lutil'
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0   make CFLAGS="-ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="-fsanitize=address -ldl -lutil -ggdb -Wno-error" LDFLAGS=" -ldl -lutil -fsanitize=address" -j 10
popd

cp ./aflrun_build/binutils/nm-new ./nm-new.aflrun
