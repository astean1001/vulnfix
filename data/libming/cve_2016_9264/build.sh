#!/bin/bash
cd /home/yuntong/vulnfix/data/libming/cve_2016_9264/pacfix
make clean && make CFLAGS="-static -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-static -fsanitize=address -fsanitize=undefined -g"
cd /home/yuntong/vulnfix/data/libming/cve_2016_9264