#!/bin/bash
# rm -rf source
# git clone https://github.com/coreutils/coreutils.git source
# pushd source
#   git checkout ca99c52
#   # for AFL argv fuzz
#   sed -i '856i #include "/home/yuntong/vulnfix/thirdparty/AFL/experimental/argv_fuzzing/argv-fuzz-inl.h"' src/pr.c
#   sed -i '860i AFL_INIT_SET0234("./pr", "/home/yuntong/vulnfix/data/coreutils/gnubug_25023/dummy", "-m", "/home/yuntong/vulnfix/data/coreutils/gnubug_25023/dummy");' src/pr.c
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
  echo "pr.c:2243" > $TMP_DIR/BBtargets.txt
  export AFLRUN_BB_TARGETS=$TMP_DIR/BBtargets.txt
  export AFLRUN_TARGETS="pr"
  # export ADDITIONAL_FLAGS="-flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  export FORCE_UNSAFE_CONFIGURE=1
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0 ../source/configure
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0 make CFLAGS="-Wno-error -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-Wno-error -fsanitize=address -fsanitize=undefined -g" -j 10
popd

cp ./aflrun_build/src/pr ./pr.aflrun