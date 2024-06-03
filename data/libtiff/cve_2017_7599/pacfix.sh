#!/bin/bash
rm -rf pacfix
cp -r source pacfix
pushd pacfix
  ../source/configure
  make CFLAGS="-fsanitize=float-cast-overflow,address -fno-sanitize-recover=float-cast-overflow -static -ggdb" CXXFLAGS="-fsanitize=float-cast-overflow,address -fno-sanitize-recover=float-cast-overflow -static -ggdb" -j10 > make.log
  # cat make.log | grep tif_dirwrite.c
  pushd libtiff
    if [ -f backup/tif_dirwrite.c ]; then
      cp backup/tif_dirwrite.c ./tif_dirwrite.c
    fi
    mkdir -p backup
    cp tif_dirwrite.c backup
    gcc -E -DHAVE_CONFIG_H -I. -fsanitize=float-cast-overflow,address -fno-sanitize-recover=float-cast-overflow -ggdb -MT tif_dirwrite.lo -MD -MP -MF .deps/tif_dirwrite.Tpo -c tif_dirwrite.c > tif_dirwrite.c.i
    cilly --domakeCFG --gcc=/usr/bin/gcc-7 --out=tmp.c tif_dirwrite.c.i
    mv tmp.c tif_dirwrite.c.i.c
    cp tif_dirwrite.c.i.c tif_dirwrite.c
  popd
popd
/home/yuntong/pacfix/main.exe -lv_only config

# manually fix the code
# python3 /home/yuntong/vulnfix/src/add_lv.py 980 repair-out/live_variables ./source/libtiff/tif_dirwrite.c
cp tif_dirwrite.pacfix.c ./source/libtiff/tif_dirwrite.c

rm -rf smake_source && mkdir smake_source
pushd smake_source
  CC=clang CXX=clang++ ../source/configure
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake --init
  CC=clang CXX=clang++ /home/yuntong/vulnfix/thirdparty/smake/smake CFLAGS="-fsanitize=float-cast-overflow,address -fno-sanitize-recover=float-cast-overflow -static -ggdb" CXXFLAGS="-fsanitize=float-cast-overflow,address -static -ggdb" LDFLAGS="-fsanitize=float-cast-overflow,address" -j10
popd

rm -rf sparrow-out && mkdir sparrow-out
/home/yuntong/vulnfix/thirdparty/sparrow/bin/sparrow -outdir ./sparrow-out \
-frontend "cil" -unsound_alloc -unsound_const_string -unsound_recursion -unsound_noreturn_function \
-unsound_skip_global_array_init 1000 -skip_main_analysis -cut_cyclic_call -unwrap_alloc \
-entry_point "main" -max_pre_iter 10 -slice "bug=tif_dirwrite.c:980" \
./smake_source/sparrow/tools/tiffcp/*.i

dir=/home/yuntong/vulnfix/data/libtiff/cve_2017_7599
rm -rf dafl_source && mkdir dafl_source
pushd dafl_source
  DAFL_SELECTIVE_COV="$dir/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="$dir/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  CMAKE_EXPORT_COMPILE_COMMANDS=1 ../source/configure

  DAFL_SELECTIVE_COV="$dir/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="$dir/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  make CFLAGS="-fsanitize=float-cast-overflow,address -static -ggdb" CXXFLAGS="-fsanitize=float-cast-overflow,address -fno-sanitize-recover=float-cast-overflow -static -ggdb" LDFLAGS="-fsanitize=float-cast-overflow,address -fno-sanitize-recover=all" -j10
popd

rm ./tiffcp.instrumented
cp dafl_source/tools/tiffcp ./tiffcp.instrumented
cp tiffcp.instrumented ./dafl-runtime/tiffcp.instrumented

# UBSAN_OPTIONS=halt_on_error=1:exitcode=1 AFL_NO_UI=1 timeout 12h /home/yuntong/vulnfix/thirdparty/DAFL/afl-fuzz -C -t 2000ms -m none -i ./in -p /home/yuntong/vulnfix/data/libtiff/cve_2017_7599/sparrow-out/bug/slice_dfg.txt -o 2024-04-04-test -- ./tiffcp.instrumented -i @@ /tmp/out.tmp
# UBSAN_OPTIONS=halt_on_error=1:exitcode=1 AFL_NO_UI=1 timeout 12h /home/yuntong/vulnfix/thirdparty/DAFL/afl-fuzz -C -t 2000ms -m none -i ./in -p /home/yuntong/vulnfix/data/libtiff/cve_2017_7599/sparrow-out/bug/slice_dfg.txt -o 2024-04-04-k -k 0 -r 0.1 -- ./tiffcp.instrumented -i @@ /tmp/out.tmp

