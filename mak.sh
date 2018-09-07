#! /bin/bash

nasm iniblz.asm -o iniblz.bin -D_MAP=iniblz.map -l iniblz.lst -D_DEBUG0 -D_DEBUG1 "$@"
