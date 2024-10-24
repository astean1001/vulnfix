#!/bin/bash
# rm -rf source
# git clone https://github.com/vadz/libtiff.git
# mv libtiff source
# pushd source
#   git checkout 0ba5d88
# popd

export AFLRUN=/home/yuntong/vulnfix/thirdparty/AFLRun
rm -rf aflrun_build && mkdir aflrun_build
pushd aflrun_build
  mkdir temp
  TMP_DIR=$PWD/temp
  mkdir aflrun_tmp
  export AFLRUN_TMP=$PWD/aflrun_tmp
  echo "tiffcrop.c:994" > $TMP_DIR/BBtargets.txt
  export AFLRUN_BB_TARGETS=$TMP_DIR/BBtargets.txt
  export AFLRUN_TARGETS="tiffcrop"
  # export ADDITIONAL_FLAGS="-flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ../source/configure --enable-static --disable-shared --without-threads --without-lzma
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" -j10
popd

cp ./aflrun_build/tools/tiffcrop ./tiffcrop.aflrun

# $AFLRUN/afl-fuzz -C -i runtime/afl-in -o runtime/afl-run-out -t 2000 -m none -- aflrun_build/tools/tiffcrop @@ /tmp/out.tiff