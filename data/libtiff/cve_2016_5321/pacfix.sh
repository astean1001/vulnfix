#!/bin/bash
rm -rf pacfix
cp -r source pacfix
pushd pacfix
  ../source/configure
  make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" -j10
  pushd tools
    gcc -E -DHAVE_CONFIG_H -I. -I../libtiff  -I../libtiff   -static -fsanitize=address -fsanitize=undefined -g -MT tiffcrop.o -MD -MP -MF .deps/tiffcrop.Tpo -c tiffcrop.c > tiffcrop.c.i
    cilly --domakeCFG --gcc=/usr/bin/gcc-7 --out=tmp.c tiffcrop.c.i
    mv tmp.c tiffcrop.c.i.c
    cp tiffcrop.c.i.c tiffcrop.c
  popd
popd
/home/yuntong/pacfix/main.exe -lv_only config

# manually fix the code
# python3 /home/yuntong/vulnfix/src/add_lv.py 992 repair-out/live_variables ./source/tools/tiffcrop.c 
cp tiffcrop.pacfix.c ./source/tools/tiffcrop.c

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

rm ./tiffcrop.instrumented
cp dafl_source/tools/tiffcrop ./tiffcrop.instrumented
cp tiffcrop.instrumented ./dafl-runtime/tiffcrop.instrumented

# AFL_NO_UI=1 timeout 12h /home/yuntong/vulnfix/thirdparty/DAFL/afl-fuzz -C -t 2000ms -m none -i ./in -p /home/yuntong/vulnfix/data/libtiff/cve_2016_5321/sparrow-out/bug/slice_dfg.txt -o 2024-04-04-test -- ./tiffcrop.instrumented @@ /tmp/out.tmp

