#!/bin/bash
cd /home/yuntong/vulnfix/data/libxml2/cve_2016_1838/pacfix
make clean && make CFLAGS="-static -fsanitize=address -g" CXXFLAGS="-static -fsanitize=address -g" LDFLAGS="-fsanitize=address" -j10
cd /home/yuntong/vulnfix/data/libxml2/cve_2016_1838