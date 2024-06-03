#!/bin/bash
rm -rf source
git clone https://gitlab.gnome.org/GNOME/libxml2.git
mv libxml2 source
pushd source
  git checkout cbb27165
popd

rm -rf smake_source && mkdir smake_source
pushd smake_source
  CC=clang CXX=clang++ ../source/autogen.sh
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake --init
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10
popd

rm -rf sparrow-out && mkdir sparrow-out
/home/yuntong/vulnfix/thirdparty/sparrow/bin/sparrow -outdir ./sparrow-out \
-frontend "cil" -unsound_alloc -unsound_const_string -unsound_recursion -unsound_noreturn_function \
-unsound_skip_global_array_init 1000 -skip_main_analysis -cut_cyclic_call -unwrap_alloc \
-entry_point "main" -max_pre_iter 10 -slice "bug=parser.c:9837" \
./smake_source/sparrow/xmllint/*.i

rm -rf dafl_source && mkdir dafl_source
pushd dafl_source
  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/libxml2/cve_2016_1838/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/libxml2/cve_2016_1838/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  CMAKE_EXPORT_COMPILE_COMMANDS=1 ../source/autogen.sh

  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/libxml2/cve_2016_1838/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/libxml2/cve_2016_1838/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10
popd

rm -rf raw_build && mkdir raw_build
pushd raw_build
  ../source/autogen.sh
  make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10
popd

# aflgo
export AFLGO=/home/yuntong/vulnfix/thirdparty/aflgo
rm -rf aflgo_build && mkdir aflgo_build
pushd aflgo_build
  # first build
  mkdir temp
  TMP_DIR=$PWD/temp
  echo "parser.c:9837" > $TMP_DIR/BBtargets.txt
  ADDITIONAL_FLAGS="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ ../source/autogen.sh
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10
  # generate distance
  cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt \
            && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
  cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt \
            && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
  $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR xmllint
  # second build
  make clean
  ADDITIONAL_FLAGS="-distance=$TMP_DIR/distance.cfg.txt"
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ ../source/autogen.sh
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10
popd

# windranger
rm -rf windranger_build && mkdir windranger_build
WINDRANGER_DIR=/home/yuntong/vulnfix/thirdparty/WindRanger
pushd windranger_build
  bin_name=xmllint
  OLD_PATH=$PATH
  export PATH=/usr/lib/llvm-10/bin:/root/go/bin:$PATH
  CC=gclang CXX=gclang++ ../source/configure
  make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address  -g" -j 32
  get-bc $bin_name
  mkdir temp
  echo "parser.c:9837" > temp/target.txt
  TARGET_FILE=$PWD/temp/target.txt
  cp $bin_name.bc temp
  pushd temp
    $WINDRANGER_DIR/windranger/instrument/bin/cbi --targets=$TARGET_FILE ./$bin_name.bc
    $WINDRANGER_DIR/windranger/fuzz/afl-clang-fast -lm -lz -fsanitize=address -g ./$bin_name.ci.bc -o $bin_name.windranger
    # run command: $WINDRANGER_DIR/windranger/fuzz/afl-fuzz -m none -d -i seed -o out -C -- ./tiffcrop.windranger @@ /tmp/out.tif
    # you need to copy distance.txt, targets.txt, condition_info.txt if you want to run this in other directory
  popd
  export PATH=$OLD_PATH
popd

cp raw_build/xmllint ./xmllint
cp dafl_source/xmllint ./xmllint.instrumented
cp aflgo_build/xmllint ./xmllint.aflgo
