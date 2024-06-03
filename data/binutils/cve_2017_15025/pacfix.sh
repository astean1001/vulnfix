#!/bin/bash
rm -rf source
git clone https://github.com/bminor/binutils-gdb.git
mv binutils-gdb source
pushd source/
  git checkout 515f23e63c0074ab531bc954f84ca40c6281a724
popd

cp dwarf2.pacfix.c source/bfd/dwarf2.c

rm -rf pacfix
cp -r source pacfix

pushd pacfix
  ASAN_OPTIONS=detect_leaks=0 CC=gcc CXX=g++ CFLAGS="-DFORTIFY_SOURCE=2 -fno-omit-frame-pointer -fsanitize=address -ggdb -Wno-error" CXXFLAGS="$CFLAGS" ../source/configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim LIBS='-ldl -lutil'
  ASAN_OPTIONS=detect_leaks=0 make CFLAGS="-ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="-fsanitize=address -ldl -lutil -ggdb -Wno-error" LDFLAGS=" -ldl -lutil -fsanitize=address" -j 10
  pushd bfd
    gcc -E -fno-optimize-sibling-calls -fno-strict-aliasing -fno-asm -std=c99 -DHAVE_CONFIG_H -I. -I. -I. -I./../include -DHAVE_x86_64_elf64_vec -DHAVE_i386_elf32_vec -DHAVE_iamcu_elf32_vec -DHAVE_x86_64_elf32_vec -DHAVE_i386_aout_linux_vec -DHAVE_i386_pei_vec -DHAVE_x86_64_pei_vec -DHAVE_l1om_elf64_vec -DHAVE_k1om_elf64_vec -DHAVE_elf64_le_vec -DHAVE_elf64_be_vec -DHAVE_elf32_le_vec -DHAVE_elf32_be_vec -DHAVE_plugin_vec -DBINDIR=\"/usr/local/bin\" -W -Wall -Wstrict-prototypes -Wmissing-prototypes -Wshadow -Wstack-usage=262144 -Werror -I./../zlib -ldl -lutil -fsanitize=address -ggdb -Wno-error -MT dwarf2.lo -MD -MP -MF .deps/dwarf2.Tpo -c -DDEBUGDIR=\"/usr/local/lib/debug\" ./dwarf2.c -lm -s > dwarf2.c.i
    cilly --domakeCFG --gcc=/usr/bin/gcc-7 --out=tmp.c dwarf2.c.i
    mv tmp.c ./dwarf2.c.i.c 
    cp dwarf2.c.i.c dwarf2.c
  popd
popd
/home/yuntong/pacfix/main.exe -lv_only config

cp dwarf2.pacfix.c source/bfd/dwarf2.c

rm -rf smake_source
mkdir smake_source
pushd smake_source
  # Build with Smake
  ASAN_OPTIONS=detect_leaks=0 CC=clang CXX=clang++ CMAKE_EXPORT_COMPILE_COMMANDS=1 CFLAGS="-DFORTIFY_SOURCE=2 -fno-omit-frame-pointer -fsanitize=address -ggdb -Wno-error" CXXFLAGS="$CFLAGS" ../source/configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim LIBS='-ldl -lutil'
  /home/yuntong/vulnfix/thirdparty/smake/smake --init
  ASAN_OPTIONS=detect_leaks=0 /home/yuntong/vulnfix/thirdparty/smake/smake CFLAGS="-ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="-fsanitize=address -ldl -lutil -ggdb -Wno-error" LDFLAGS=" -ldl -lutil -fsanitize=address" -j 10
popd

rm -rf sparrow-out
mkdir sparrow-out
# Run Sparrow
/home/yuntong/vulnfix/thirdparty/sparrow/bin/sparrow -outdir ./sparrow-out \
-frontend "cil" -unsound_alloc -unsound_const_string -unsound_recursion -unsound_noreturn_function \
-unsound_skip_global_array_init 1000 -skip_main_analysis -cut_cyclic_call -unwrap_alloc \
-entry_point "main" -max_pre_iter 10 -slice "bug=dwarf2.c:2441" \
./smake_source/sparrow/binutils/nm-new/*.i

rm -rf dafl_source
mkdir dafl_source
pushd dafl_source
  # Run DAFL Instrumentation
  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/binutils/cve_2017_15025/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/binutils/cve_2017_15025/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  CMAKE_EXPORT_COMPILE_COMMANDS=1 CFLAGS="-DFORTIFY_SOURCE=2 -fno-omit-frame-pointer -fsanitize=address -ggdb -Wno-error" \
  CXXFLAGS="$CFLAGS" ../source/configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim LIBS='-ldl -lutil'

  DAFL_SELECTIVE_COV="/home/yuntong/vulnfix/data/binutils/cve_2017_15025/sparrow-out/bug/slice_func.txt" \
  DAFL_DFG_SCORE="/home/yuntong/vulnfix/data/binutils/cve_2017_15025/sparrow-out/bug/slice_dfg.txt" \
  ASAN_OPTIONS=detect_leaks=0 CC=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast CXX=/home/yuntong/vulnfix/thirdparty/DAFL/afl-clang-fast++ \
  make CFLAGS="-ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="-fsanitize=address -ldl -lutil -ggdb -Wno-error" \
  LDFLAGS=" -ldl -lutil -fsanitize=address" -j 10
popd

cp ./dafl_source/binutils/nm-new ./nm-new.instrumented