#!/bin/bash
rm -rf pacfix
cp -r source pacfix
pushd pacfix
  ../source/autogen.sh --disable-silent-rules
  make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10 > make.log
  # cat make.log | grep parser.c
  gcc -E -DHAVE_CONFIG_H -I. -I../source -I./include -I../source/include -D_REENTRANT -fsanitize=address -g -MT parser.lo -MD -MP -MF .deps/parser.Tpo -c parser.c > parser.c.i
  cilly --domakeCFG --gcc=/usr/bin/gcc-7 --out=tmp.c parser.c.i
  mv tmp.c parser.c.i.c
  cp parser.c.i.c parser.c
popd
/home/yuntong/pacfix/main.exe -lv_only config

# manually fix the code
# python3 /home/yuntong/vulnfix/src/add_lv.py 4079 repair-out/live_variables ./source/parser.c
cp parser.pacfix.c ./source/parser.c

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
-entry_point "main" -max_pre_iter 10 -slice "bug=parser.c:4079" \
./smake_source/sparrow/xmllint/*.i

rm -rf dafl_source && mkdir dafl_source
pushd dafl_source
  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/libxml2/cve_2012_5134/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/libxml2/cve_2012_5134/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  CMAKE_EXPORT_COMPILE_COMMANDS=1 ../source/autogen.sh

  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/libxml2/cve_2012_5134/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/libxml2/cve_2012_5134/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10
popd

cp dafl_source/xmllint ./xmllint.instrumented

# AFL_NO_UI=1 timeout 12h /home/yuntong/vulnfix/thirdparty/DAFL/afl-fuzz -C -t 2000ms -m none -i ./in -p /home/yuntong/vulnfix/data/libtiff/cve_2016_5321/sparrow-out/bug/slice_dfg.txt -o 2024-04-04-test -- ./tiffcrop.instrumented @@ /tmp/out.tmp

