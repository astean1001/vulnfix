#!/bin/bash
cd /home/yuntong/vulnfix/data/coreutils/gnubug_25003/pacfix
make clean && make CFLAGS="-Wno-error -fsanitize=address -fsanitize=undefined -g" CXXFLAGS="-Wno-error -fsanitize=address -fsanitize=undefined -g" -j10
cd /home/yuntong/vulnfix/data/coreutils/gnubug_25003