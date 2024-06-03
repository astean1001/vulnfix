#!/bin/bash
cd /home/yuntong/vulnfix/data/libtiff/cve_2017_7600/pacfix
make clean && make CFLAGS="-fsanitize=float-cast-overflow,address -fno-sanitize-recover=all -static -ggdb" CXXFLAGS="-fsanitize=float-cast-overflow,address -fno-sanitize-recover=all -static -ggdb" LDFLAGS="-fsanitize=float-cast-overflow,address -fno-sanitize-recover=all" -j10
cd /home/yuntong/vulnfix/data/libtiff/cve_2017_7600