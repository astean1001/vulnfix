#!/bin/bash
rm -rf pacfix
cp -r source pacfix
pushd pacfix
  ../source/configure --disable-freetype
  make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" -j 10 > make.log
  # cat make.log | grep jdmarker.c
  pushd util
    gcc -E -DHAVE_CONFIG_H -I. -I../source -Wall -fsanitize=address -fsanitize=undefined -g -MT jdmarker.lo -MD -MP -MF .deps/jdmarker.Tpo -c jdmarker.c > jdmarker.c.i
    cilly --domakeCFG --gcc=/usr/bin/gcc-7 --out=tmp.c jdmarker.c.i
    mv tmp.c jdmarker.c.i.c
    cp jdmarker.c.i.c jdmarker.c
  popd
popd
/home/yuntong/pacfix/main.exe -lv_only config

# manually fix the code
# python3 /home/yuntong/vulnfix/src/add_lv.py 327 repair-out/live_variables ./source/jdmarker.c 
cp jdmarker.pacfix.c ./source/jdmarker.c


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

cp dafl_source/djpeg ./djpeg.instrumented

# AFL_NO_UI=1 timeout 12h /home/yuntong/vulnfix/thirdparty/DAFL/afl-fuzz -C -t 2000ms -m none -i ./in -p /home/yuntong/vulnfix/data/libtiff/cve_2016_5321/sparrow-out/bug/slice_dfg.txt -o 2024-04-04-test -- ./tiffcrop.instrumented @@ /tmp/out.tmp

