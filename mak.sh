#! /bin/bash
gcc -g test.c -o test
nasm test.asm -o test.com -I ../lmacros/ -l test.lst
gcc -g test2.c -o test2
