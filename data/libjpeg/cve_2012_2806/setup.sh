#!/bin/bash
rm -rf source
git clone https://github.com/libjpeg-turbo/libjpeg-turbo.git
mv libjpeg-turbo source

pushd source
  git checkout 4f24016
  autoreconf -fiv
popd

rm -rf smake_source && mkdir smake_source
pushd smake_source
  CC=clang CXX=clang++ ../source/configure
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake --init
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" -j 10
popd

rm -rf sparrow-out && mkdir sparrow-out
/home/yuntong/vulnfix/thirdparty/sparrow/bin/sparrow -outdir ./sparrow-out \
-frontend "clang" -unsound_alloc -unsound_const_string -unsound_recursion -unsound_noreturn_function \
-unsound_skip_global_array_init 1000 -skip_main_analysis -cut_cyclic_call -unwrap_alloc \
-entry_point "get_sos" -max_pre_iter 10 -slice "bug=jdmarker.c:327" \
./smake_source/sparrow/djpeg/*.i ./smake_source/sparrow/jdmarker.o.i

rm -rf dafl_source && mkdir dafl_source
pushd dafl_source
  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/libjpeg/cve_2012_2806/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/libjpeg/cve_2012_2806/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  ../source/configure

  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/libjpeg/cve_2012_2806/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/libjpeg/cve_2012_2806/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" -j 10
popd

rm -rf raw_build && mkdir raw_build
pushd raw_build
  ../source/configure 
  make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" -j 10
popd

# aflgo
export AFLGO=/home/yuntong/vulnfix/thirdparty/aflgo
rm -rf aflgo_build && mkdir aflgo_build
pushd aflgo_build
  # first build
  mkdir temp
  TMP_DIR=$PWD/temp
  echo "jdmarker.c:327" > $TMP_DIR/BBtargets.txt
  ADDITIONAL_FLAGS="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ ../source/configure
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" -j10
  # generate distance
  cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt \
            && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
  cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt \
            && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
  $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR djpeg
  # second build
  make clean
  ADDITIONAL_FLAGS="-distance=$TMP_DIR/distance.cfg.txt"
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ ../source/configure
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -fsanitize=undefined -g" -j10
popd


# windranger
rm -rf windranger_build && mkdir windranger_build
WINDRANGER_DIR=/home/yuntong/vulnfix/thirdparty/WindRanger
pushd windranger_build
  bin_name=djpeg
  OLD_PATH=$PATH
  export PATH=/usr/lib/llvm-10/bin:/root/go/bin:$PATH
  CC=gclang CXX=gclang++ ../source/configure
  make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" -j 32
  mkdir temp
  echo "jdmarker.c:327" > temp/target.txt
  TARGET_FILE=$PWD/temp/target.txt
  get-bc $bin_name
  cp $bin_name.bc temp
  pushd temp
    $WINDRANGER_DIR/windranger/instrument/bin/cbi --targets=$TARGET_FILE ./$bin_name.bc
    $WINDRANGER_DIR/windranger/fuzz/afl-clang-fast -ljpeg -lm -lz -fsanitize=address -fsanitize=undefined -g ./$bin_name.ci.bc -o $bin_name.windranger
    # run command: $WINDRANGER_DIR/windranger/fuzz/afl-fuzz -m none -d -i seed -o out -C -- ./tiffcrop.windranger @@ /tmp/out.tif
    # you need to copy distance.txt, targets.txt, condition_info.txt if you want to run this in other directory
  popd
  export PATH=$OLD_PATH
popd

cp raw_build/djpeg ./djpeg
cp dafl_source/djpeg ./djpeg.instrumented
cp aflgo_build/djpeg ./djpeg.aflgo