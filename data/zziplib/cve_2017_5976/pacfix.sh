#!/bin/bash
rm -rf pacfix
cp -r source pacfix
pushd pacfix
  ../source/configure
  make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j10 > make.log
  # cat make.log | grep memdisk.c
  pushd zzip
    gcc -E -DHAVE_CONFIG_H -I.. -I../../source -static -fsanitize=address -g -MT memdisk.lo -MD -MP -MF .deps/memdisk.Tpo -c memdisk.c > memdisk.c.i
    cilly --domakeCFG --gcc=/usr/bin/gcc-7 --out=tmp.c memdisk.c.i
    mv tmp.c memdisk.c.i.c
    cp memdisk.c.i.c memdisk.c
  popd
popd
/home/yuntong/pacfix/main.exe -lv_only config

# manually fix the code
# python3 /home/yuntong/vulnfix/src/add_lv.py 248 repair-out/live_variables ./source/zzip/memdisk.c
cp memdisk.pacfix.c ./source/zzip/memdisk.c

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
-entry_point "main" -max_pre_iter 10 -slice "bug=memdisk.c:224" \
./smake_source/sparrow/bins/unzzipcat-mem/*.i

rm -rf dafl_source && mkdir dafl_source
pushd dafl_source
  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/zziplib/cve_2017_5974/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/zziplib/cve_2017_5974/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  CMAKE_EXPORT_COMPILE_COMMANDS=1 ../source/configure

  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/zziplib/cve_2017_5974/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/zziplib/cve_2017_5974/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j10
popd

cp dafl_source/bins/unzzipcat-mem ./unzzipcat-mem.instrumented

# AFL_NO_UI=1 timeout 12h /home/yuntong/vulnfix/thirdparty/DAFL/afl-fuzz -C -t 2000ms -m none -i ./in -p /home/yuntong/vulnfix/data/libtiff/cve_2016_5321/sparrow-out/bug/slice_dfg.txt -o 2024-04-04-test -- ./tiffcrop.instrumented @@ /tmp/out.tmp

