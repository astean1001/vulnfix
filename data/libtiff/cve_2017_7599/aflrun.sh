#!/bin/bash
# commit_id=3cfd62d

# rm -rf source
# git clone https://github.com/vadz/libtiff.git
# mv libtiff source
# pushd source
#   git checkout $commit_id
# popd

export AFLRUN=/home/yuntong/vulnfix/thirdparty/AFLRun
rm -rf aflrun_build && mkdir aflrun_build
pushd aflrun_build
  mkdir temp
  TMP_DIR=$PWD/temp
  mkdir aflrun_tmp
  export AFLRUN_TMP=$PWD/aflrun_tmp
  echo "tif_dirwrite.c:980" > $TMP_DIR/BBtargets.txt
  export AFLRUN_BB_TARGETS=$TMP_DIR/BBtargets.txt
  export AFLRUN_TARGETS="tiffcp"
  # export ADDITIONAL_FLAGS="-flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  export FORCE_UNSAFE_CONFIGURE=1
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0 ../source/configure
  CC=$AFLRUN/afl-clang-lto CXX=$AFLRUN/afl-clang-lto++ ASAN_OPTIONS=detect_leaks=0 make CFLAGS="-fsanitize=float-cast-overflow,address -static -ggdb" CXXFLAGS="-fsanitize=float-cast-overflow,address -static -ggdb" LDFLAGS="-fsanitize=float-cast-overflow,address -fno-sanitize-recover=all" -j10
popd
cp aflrun_build/tools/tiffcp ./tiffcp.aflrun

# AFL_NO_UI=1 timeout 12h /home/yuntong/vulnfix/thirdparty/DAFL/afl-fuzz -C -t 2000ms -m none -i ./in -p /home/yuntong/vulnfix/data/libtiff/cve_2017_7599/sparrow-out/bug/slice_dfg.txt -o 2024-04-04-test -- ./tiffcp.instrumented -i @@ /tmp/out.tmp
# AFL_NO_UI=1 timeout 12h /home/yuntong/vulnfix/thirdparty/DAFL/afl-fuzz -C -t 2000ms -m none -i ./in -p /home/yuntong/vulnfix/data/libtiff/cve_2017_7599/sparrow-out/bug/slice_dfg.txt -o 2024-04-04-k -k 0 -r 0.1 -- ./tiffcp.instrumented -i @@ /tmp/out.tmp

