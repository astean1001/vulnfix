#!/bin/bash
cd /home/yuntong/vulnfix/data/libtiff/cve_2016_5321/pacfix
make clean && make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" LDFLAGS="-fsanitize=address -fsanitize=undefined" -j10
cd /home/yuntong/vulnfix/data/libtiff/cve_2016_5321