#!/bin/bash
# rm -rf source
# git clone https://github.com/coreutils/coreutils.git source
# pushd source
#   git checkout 68c5eec
#   # for AFL argv fuzz
#   sed -i '1283i #include "/home/yuntong/vulnfix/thirdparty/AFL/experimental/argv_fuzzing/argv-fuzz-inl.h"' src/split.c
#   sed -i '1288i AFL_INIT_SET02("./split", "/home/yuntong/vulnfix/data/coreutils/gnubug_25003/dummy");' src/split.c
#   # avoid writing out a lot of files during fuzzing
#   sed -i '595i return false;' src/split.c
#   # not bulding man pages
#   sed -i '229d' Makefile.am
#   # change gnulib source
#   sed -i "s|git://git.sv.gnu.org/gnulib.git|https://github.com/coreutils/gnulib.git|g" .gitmodules
#   sed -i "s|git://git.sv.gnu.org/gnulib|https://github.com/coreutils/gnulib.git|g" bootstrap
#   ./bootstrap
# popd

export AFLRUN=/home/yuntong/vulnfix/thirdparty/AFLRun
rm -rf aflrun_build && mkdir aflrun_build
pushd aflrun_build
  mkdir temp
  TMP_DIR=$PWD/temp
  mkdir aflrun_tmp
  export AFLRUN_TMP=$PWD/aflrun_tmp
  echo "split.c:988" > $TMP_DIR/BBtargets.txt
  export AFLRUN_BB_TARGETS=$TMP_DIR/BBtargets.txt
  export AFLRUN_TARGETS="split"
  export FORCE_UNSAFE_CONFIGURE=1
  # export ADDITIONAL_FLAGS="-flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0 ../source/configure
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0 make CFLAGS="-Wno-error -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-Wno-error -fsanitize=address -fsanitize=undefined -g" -j 10
popd

cp aflrun_build/src/split ./split.aflrun