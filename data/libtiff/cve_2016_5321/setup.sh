#!/bin/bash
rm -rf source
git clone https://github.com/vadz/libtiff.git
mv libtiff source
pushd source
  git checkout 0ba5d88
popd

rm -rf smake_source && mkdir smake_source
pushd smake_source
  CC=clang CXX=clang++ ../source/configure
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake --init
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" LDFLAGS="-fsanitize=address -fsanitize=undefined" -j10
popd

rm -rf sparrow-out && mkdir sparrow-out
/home/yuntong/vulnfix/thirdparty/sparrow/bin/sparrow -outdir ./sparrow-out \
-frontend "cil" -unsound_alloc -unsound_const_string -unsound_recursion -unsound_noreturn_function \
-unsound_skip_global_array_init 1000 -skip_main_analysis -cut_cyclic_call -unwrap_alloc \
-entry_point "main" -max_pre_iter 10 -slice "bug=tiffcrop.c:994" \
./smake_source/sparrow/tools/tiffcrop/*.i

rm -rf dafl_source && mkdir dafl_source
pushd dafl_source
  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/libtiff/cve_2016_5321/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/libtiff/cve_2016_5321/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  CMAKE_EXPORT_COMPILE_COMMANDS=1 ../source/configure

  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/libtiff/cve_2016_5321/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/libtiff/cve_2016_5321/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps" LDFLAGS="-fsanitize=address -fsanitize=undefined" -j10
popd

rm -rf raw_build && mkdir raw_build
pushd raw_build
  ../source/configure
  make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" -j10
popd

# aflgo
export AFLGO=/home/yuntong/vulnfix/thirdparty/aflgo
rm -rf aflgo_build && mkdir aflgo_build
pushd aflgo_build
  # first build
  mkdir temp
  TMP_DIR=$PWD/temp
  echo "tiffcrop.c:994" > $TMP_DIR/BBtargets.txt
  ADDITIONAL_FLAGS="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ ../source/configure --enable-static --disable-shared --without-threads --without-lzma
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" -j10
  # generate distance
  cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt \
            && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
  cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt \
            && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
  $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR tiffcrop
  # second build
  make clean
  ADDITIONAL_FLAGS="-distance=$TMP_DIR/distance.cfg.txt"
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ ../source/configure  --enable-static --disable-shared --without-threads --without-lzma
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" -j10
popd

# beacon
rm -rf beacon_build && mkdir beacon_build
BEACON_DIR=/home/yuntong/vulnfix/thirdparty/Beacon
pushd beacon_build
  OLD_PATH=$PATH
  export PATH=$BEACON_DIR/llvm4/bin:$PATH
  CC=clang CXX=clang++ ../source/configure  --enable-static --disable-shared --without-threads --without-lzma
  ADDITIONAL_FLAGS="-flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" -j10
  mkdir temp
  echo "tiffcrop.c:994" > temp/target.txt
  cp tools/tiffcrop.0.0.preopt.bc temp/tiffcrop.bc
  pushd temp
    $BEACON_DIR/precondInfer tiffcrop.bc --target-file=target.txt --join-bound=5 > precond.log 2>&1
    $BEACON_DIR/Ins -output=tiffcrop.bc -byte -blocks=bbreaches__benchmark_target_line -afl -log=ins.log -load=range_res.txt ins.bc
  popd
  export PATH=$OLD_PATH
popd

# windranger
rm -rf windranger_build && mkdir windranger_build
WINDRANGER_DIR=/home/yuntong/vulnfix/thirdparty/WindRanger
pushd windranger_build
  OLD_PATH=$PATH
  export PATH=/usr/lib/llvm-10/bin:/root/go/bin:$PATH
  CC=gclang CXX=gclang++ ../source/configure --enable-static --disable-shared --without-threads --without-lzma
  make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" -j 32
  get-bc tools/tiffcrop
  mkdir temp
  echo "tiffcrop.c:994" > temp/target.txt
  TARGET_FILE=$PWD/temp/target.txt
  cp tools/tiffcrop.bc temp/tiffcrop.bc
  pushd temp
    $WINDRANGER_DIR/windranger/instrument/bin/cbi --targets=$TARGET_FILE ./tiffcrop.bc
    $WINDRANGER_DIR/windranger/fuzz/afl-clang-fast -ljpeg -lm -lz -fsanitize=address -fsanitize=undefined -g ./tiffcrop.ci.bc -o tiffcrop.windranger
    # run command: $WINDRANGER_DIR/windranger/fuzz/afl-fuzz -m none -d -i seed -o out -C -- ./tiffcrop.windranger @@ /tmp/out.tif
    # you need to copy distance.txt, targets.txt, condition_info.txt if you want to run this in other directory
  popd
  export PATH=$OLD_PATH
popd

cp raw_build/tools/tiffcrop ./tiffcrop
cp dafl_source/tools/tiffcrop ./tiffcrop.instrumented
cp aflgo_build/tools/tiffcrop ./tiffcrop.aflgo
cp beacon_build/tools/tiffcrop ./tiffcrop.beacon
cp windranger_build/temp/windranger.out ./tiffcrop.windranger

