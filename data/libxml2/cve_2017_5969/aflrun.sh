#!/bin/bash

# rm -rf source
# git clone https://gitlab.gnome.org/GNOME/libxml2.git
# mv libxml2 source
# pushd source
#   git checkout 362b3229
# popd

export AFLRUN=/home/yuntong/vulnfix/thirdparty/AFLRun
rm -rf aflrun_build && mkdir aflrun_build
pushd aflrun_build
  mkdir temp
  TMP_DIR=$PWD/temp
  mkdir aflrun_tmp
  export AFLRUN_TMP=$PWD/aflrun_tmp
  echo "valid.c:1181" > $TMP_DIR/BBtargets.txt
  export AFLRUN_BB_TARGETS=$TMP_DIR/BBtargets.txt
  export AFLRUN_TARGETS="xmllint"
  # export ADDITIONAL_FLAGS="-flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  export FORCE_UNSAFE_CONFIGURE=1
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0 ../source/autogen.sh
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0 make  CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10
popd

cp aflrun_build/xmllint ./xmllint.aflrun
