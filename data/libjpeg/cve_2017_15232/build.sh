#!/bin/bash
cd /home/yuntong/vulnfix/data/libjpeg/cve_2017_15232/pacfix
make clean && make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g" -j10
cd /home/yuntong/vulnfix/data/libjpeg/cve_2017_15232