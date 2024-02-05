#!/bin/bash
rm -rf source
git clone https://github.com/gdraheim/zziplib.git
mv zziplib source
pushd source
  git checkout 33d6e9c
  pushd docs
    wget https://github.com/LuaDist/libzzip/raw/master/docs/zziplib-manpages.tar
  popd
popd

rm -rf smake_source && mkdir smake_source
pushd smake_source
  CC=clang CXX=clang++ ../source/configure
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake --init
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j10
popd

rm -rf sparrow-out && mkdir sparrow-out
/home/yuntong/vulnfix/thirdparty/sparrow/bin/sparrow -outdir ./sparrow-out \
-frontend "cil" -unsound_alloc -unsound_const_string -unsound_recursion -unsound_noreturn_function \
-unsound_skip_global_array_init 1000 -skip_main_analysis -cut_cyclic_call -unwrap_alloc \
-entry_point "main" -max_pre_iter 10 -slice "bug=memdisk.c:182" \
./smake_source/sparrow/bins/unzzipcat-mem/*.i

rm -rf dafl_source && mkdir dafl_source
pushd dafl_source
  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/zziplib/cve_2017_5975/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/zziplib/cve_2017_5975/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  CMAKE_EXPORT_COMPILE_COMMANDS=1 ../source/configure

  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/zziplib/cve_2017_5975/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/zziplib/cve_2017_5975/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j10
popd

rm -rf raw_build && mkdir raw_build
pushd raw_build
  ../source/configure
  make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j10
popd

# aflgo
export AFLGO=/home/yuntong/vulnfix/thirdparty/aflgo
rm -rf aflgo_build && mkdir aflgo_build
pushd aflgo_build
  # first build
  mkdir temp
  TMP_DIR=$PWD/temp
  echo "memdisk.c:182" > $TMP_DIR/BBtargets.txt
  ADDITIONAL_FLAGS="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ ../source/configure
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10
  # generate distance
  cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt \
            && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
  cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt \
            && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
  $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR unzzipcat-mem
  # second build
  make clean
  ADDITIONAL_FLAGS="-distance=$TMP_DIR/distance.cfg.txt"
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ ../source/configure
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ make CFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -g" CXXFLAGS="$ADDITIONAL_FLAGS -static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10
popd

cp raw_build/bins/unzzipcat-mem ./unzzipcat-mem
cp dafl_source/bins/unzzipcat-mem ./unzzipcat-mem.instrumented
cp aflgo_build/bins/unzzipcat-mem ./unzzipcat-mem.aflgo
