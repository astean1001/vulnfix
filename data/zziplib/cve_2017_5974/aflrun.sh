#!/bin/bash
# rm -rf source
# git clone https://github.com/gdraheim/zziplib.git
# mv zziplib source
# pushd source
#   git checkout 3a4ffcd
#   pushd docs
#     wget https://github.com/LuaDist/libzzip/raw/master/docs/zziplib-manpages.tar
#   popd
# popd

export AFLRUN=/home/yuntong/vulnfix/thirdparty/AFLRun
rm -rf aflrun_build && mkdir aflrun_build
pushd aflrun_build
  mkdir temp
  TMP_DIR=$PWD/temp
  mkdir aflrun_tmp
  export AFLRUN_TMP=$PWD/aflrun_tmp
  echo "memdisk.c:224" > $TMP_DIR/BBtargets.txt
  export AFLRUN_BB_TARGETS=$TMP_DIR/BBtargets.txt
  export AFLRUN_TARGETS="unzzipcat-mem"
  # export ADDITIONAL_FLAGS="-flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  export FORCE_UNSAFE_CONFIGURE=1
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0 ../source/configure
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0 make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j10
popd

cp aflrun_build/bins/unzzipcat-mem ./unzzipcat-mem.aflrun
