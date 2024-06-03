#!/bin/bash
cd /home/yuntong/vulnfix/data/binutils/cve_2017_15025/pacfix/
make clean && ASAN_OPTIONS=detect_leaks=0 make CFLAGS="-ldl -lutil -fsanitize=address -ggdb -Wno-error" CXXFLAGS="-fsanitize=address -ldl -lutil -ggdb -Wno-error" LDFLAGS=" -ldl -lutil -fsanitize=address" -j10
cd /home/yuntong/vulnfix/data/binutils/cve_2017_15025/