#! /bin/bash

# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

gcc -g test.c -o test
nasm test.asm -o test.com -I ../lmacros/ -l test.lst
gcc -g test2.c -o test2

