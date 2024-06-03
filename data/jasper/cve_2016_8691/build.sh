#!/bin/bash
cd /home/yuntong/vulnfix/data/jasper/cve_2016_8691/pacfix
make clean && make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j10
cd /home/yuntong/vulnfix/data/jasper/cve_2016_8691