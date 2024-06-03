#!/bin/bash
rm -rf source
unzip source.zip

pushd source
  autoreconf -i
popd


rm -rf pacfix
cp -r source pacfix

pushd pacfix
  ../source/configure 
  make  CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j 10 > make.log
  cat make.log | grep jpc_dec.c
  pushd src/libjasper/jpc
    gcc -DHAVE_CONFIG_H -I. -I../../../../source/src/libjasper/jpc -I../../../src/libjasper/include/jasper -I../../../../source/src/libjasper/include -fsanitize=address -g -MT jpc_dec.lo -MD -MP -MF .deps/jpc_dec.Tpo -c jpc_dec.c > jpc_dec.c.i
    cilly --domakeCFG --gcc=/usr/bin/gcc-7 --out=tmp.c jpc_dec.c.i
    mv tmp.c jpc_dec.c.i.c 
    cp jpc_dec.c.i.c jpc_dec.c
  popd
popd
/home/yuntong/pacfix/main.exe -lv_only config

rm -rf smake_source && mkdir smake_source
pushd smake_source
  CC=clang CXX=clang++ ../source/configure
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake --init
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j 10
popd

rm -rf sparrow-out && mkdir sparrow-out
/home/yuntong/vulnfix/thirdparty/sparrow/bin/sparrow -outdir ./sparrow-out \
-frontend "clang" -unsound_alloc -unsound_const_string -unsound_recursion -unsound_noreturn_function \
-unsound_skip_global_array_init 1000 -skip_main_analysis -cut_cyclic_call -unwrap_alloc \
-entry_point "jpc_dec_process_siz" -max_pre_iter 10 -slice "bug=jpc_dec.c:1193" \
./smake_source/sparrow/src/appl/imginfo/*.i ./smake_source/sparrow/src/libjasper/jpc/*.i

rm -rf dafl_source && mkdir dafl_source
pushd dafl_source
  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/jasper/cve_2016_8691/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/jasper/cve_2016_8691/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  ../source/configure

  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/jasper/cve_2016_8691/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/jasper/cve_2016_8691/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j 10
popd

rm -rf raw_build && mkdir raw_build
pushd raw_build
  ../source/configure 
  make  CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j 10
popd

cp dafl_source/src/appl/imginfo ./imginfo.instrumented
