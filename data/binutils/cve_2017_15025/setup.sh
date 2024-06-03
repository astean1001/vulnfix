#!/bin/bash
rm -rf source
git clone https://github.com/bminor/binutils-gdb.git
mv binutils-gdb source
cd source/
git checkout 515f23e63c0074ab531bc954f84ca40c6281a724

cd ..
rm -rf smake_source
mkdir smake_source
cd smake_source

# Build with Smake
ASAN_OPTIONS=detect_leaks=0 CC=clang CXX=clang++ CMAKE_EXPORT_COMPILE_COMMANDS=1 CFLAGS="-DFORTIFY_SOURCE=2 -fno-omit-frame-pointer -fsanitize=address -ggdb -Wno-error" CXXFLAGS="$CFLAGS" ../source/configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim LIBS='-ldl -lutil'

/home/yuntong/vulnfix/thirdparty/smake/smake --init

ASAN_OPTIONS=detect_leaks=0 /home/yuntong/vulnfix/thirdparty/smake/smake CFLAGS="-ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="-fsanitize=address -ldl -lutil -ggdb -Wno-error" LDFLAGS=" -ldl -lutil -fsanitize=address" -j 10

# Move smake result to sparrow
cd sparrow/binutils
cp -R ./nm-new ../../../nm-new-sparrow
cd ../../../
rm -rf sparrow-out
mkdir sparrow-out

# Run Sparrow
/home/yuntong/vulnfix/thirdparty/sparrow/bin/sparrow -outdir ./sparrow-out \
-frontend "cil" -unsound_alloc -unsound_const_string -unsound_recursion -unsound_noreturn_function \
-unsound_skip_global_array_init 1000 -skip_main_analysis -cut_cyclic_call -unwrap_alloc \
-entry_point "main" -max_pre_iter 10 -slice "bug=dwarf2.c:2441" \
./nm-new-sparrow/*.i

rm -rf dafl_source
mkdir dafl_source
cd dafl_source

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

cd ..
cp ./dafl_source/binutils/nm-new ./nm-new.instrumented

rm -rf raw_build
mkdir raw_build
cd raw_build
ASAN_OPTIONS=detect_leaks=0 CC=gcc CXX=g++ CFLAGS="-DFORTIFY_SOURCE=2 -fno-omit-frame-pointer -fsanitize=address -ggdb -Wno-error" CXXFLAGS="$CFLAGS" ../source/configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim LIBS='-ldl -lutil'
ASAN_OPTIONS=detect_leaks=0 make CFLAGS="-ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="-fsanitize=address -ldl -lutil -ggdb -Wno-error" LDFLAGS=" -ldl -lutil -fsanitize=address" -j 10

cd ..
cp ./raw_build/binutils/nm-new ./nm-new


# aflgo
export AFLGO=/home/yuntong/vulnfix/thirdparty/aflgo
rm -rf aflgo_build && mkdir aflgo_build
pushd aflgo_build
  # first build
  mkdir temp
  TMP_DIR=$PWD/temp
  echo "dwarf2.c:2441" > $TMP_DIR/BBtargets.txt
  ADDITIONAL_FLAGS="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ ../source/configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim LIBS='-ldl -lutil'
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ make CFLAGS="$ADDITIONAL_FLAGS -ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="$ADDITIONAL_FLAGS -ldl -lutil -fsanitize=address -ggdb -Wno-error" -j10
  # generate distance
  cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt \
            && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
  cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt \
            && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
  $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR nm-new
  # second build
  make clean
  ADDITIONAL_FLAGS="-distance=$TMP_DIR/distance.cfg.txt"
  # AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ ../source/configure  --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim LIBS='-ldl -lutil'
  AFL_PATH=$AFLGO CC=$AFLGO/afl-clang-fast CXX=$AFLGO/afl-clang-fast++ make CFLAGS="$ADDITIONAL_FLAGS -ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="$ADDITIONAL_FLAGS -ldl -lutil -fsanitize=address -ggdb -Wno-error" -j10
popd

# beacon
rm -rf beacon_build && mkdir beacon_build
BEACON_DIR=/home/yuntong/vulnfix/thirdparty/Beacon
pushd beacon_build
  OLD_PATH=$PATH
  export PATH=$BEACON_DIR/llvm4/bin:$PATH
  CC=clang CXX=clang++ ../source/configure  --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim LIBS='-ldl -lutil'
  ADDITIONAL_FLAGS="-flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
  make CFLAGS="$ADDITIONAL_FLAGS -ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="$ADDITIONAL_FLAGS -ldl -lutil -fsanitize=address -ggdb -Wno-error" -j10
  mkdir temp
  echo "dwarf2.c:2441" > temp/target.txt
  cp binutils/nm-new.0.0.preopt.bc temp/nm-new.bc
  pushd temp
    $BEACON_DIR/precondInfer nm-new.bc --target-file=target.txt --join-bound=5 > precond.log 2>&1
    $BEACON_DIR/Ins -output=nm-new.bc -byte -blocks=bbreaches__benchmark_target_line -afl -log=ins.log -load=range_res.txt ins.bc
  popd
  export PATH=$OLD_PATH
popd

# windranger
rm -rf windranger_build && mkdir windranger_build
WINDRANGER_DIR=/home/yuntong/vulnfix/thirdparty/WindRanger
pushd windranger_build
  bin_name=nm-new
  OLD_PATH=$PATH
  export PATH=/usr/lib/llvm-10/bin:/root/go/bin:$PATH
  CC=gclang CXX=gclang++ ../source/configure  --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim LIBS='-ldl -lutil'
  make CFLAGS="-ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="-ldl -lutil -fsanitize=address -ggdb -Wno-error" -j 32
  get-bc binutils/$bin_name
  mkdir temp
  echo "dwarf2.c:2441" > temp/target.txt
  TARGET_FILE=$PWD/temp/target.txt
  cp binutils/$bin_name.bc temp
  pushd temp
    $WINDRANGER_DIR/windranger/instrument/bin/cbi --targets=$TARGET_FILE ./$bin_name.bc
    $WINDRANGER_DIR/windranger/fuzz/afl-clang-fast -ldl -lutil -fsanitize=address -ggdb -Wno-error ./$bin_name.ci.bc -o $bin_name.windranger
    # run command: $WINDRANGER_DIR/windranger/fuzz/afl-fuzz -m none -d -i seed -o out -C -- ./tiffcrop.windranger @@ /tmp/out.tif
    # you need to copy distance.txt, targets.txt, condition_info.txt if you want to run this in other directory
  popd
  export PATH=$OLD_PATH
popd

cp aflgo_build/binutils/nm-new ./nm-new.aflgo