#! /bin/bash

nasm inicomp.asm -D_BRIEFLZ -o iniblz.bin -D_MAP=iniblz.map -l iniblz.lst -D_DEBUG0 -D_DEBUG1 "$@"
nasm inicomp.asm -D_LZ4 -o inilz4.bin -D_MAP=inilz4.map -l inilz4.lst -D_DEBUG0 -D_DEBUG1 "$@"
