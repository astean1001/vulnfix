#!/bin/bash
cd /home/yuntong/vulnfix/data/zziplib/cve_2017_5975/pacfix
make clean && make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" -j10
cd /home/yuntong/vulnfix/data/zziplib/cve_2017_5975