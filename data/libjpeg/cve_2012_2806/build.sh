#!/bin/bash
cd /home/yuntong/vulnfix/data/libjpeg/cve_2012_2806/pacfix
make clean && make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g"
cd /home/yuntong/vulnfix/data/libjpeg/cve_2012_2806