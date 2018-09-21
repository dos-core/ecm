#! /bin/bash
nasm instsect.asm -D_MAP=instsect.map -l instsect.lst -I../gopt/ -I../ldosboot/ -I../lmacros/ -o instsect.com
nasm -D_PAYLOAD_FAT32='"boot32fd.bin"' -D_FAT12=0 -D_FAT16=0 instsect.asm -D_MAP=instfd32.map -l instfd32.lst -I../gopt/ -I../ldosboot/ -I../lmacros/ -o instfd32.com

