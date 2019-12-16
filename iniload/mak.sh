#! /bin/bash

# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

nasm -I ../../lmacros/ inicheck.asm -o inicheck.big \
&& nasm -I ../../lmacros/ mzshim.asm -D_FILE="'inicheck.big'" \
 -D_IMAGE_EXE_IP=256 -D_IMAGE_EXE_AUTO_STACK \
 -D_IMAGE_EXE_MIN_CALC=_IMAGE_EXE_AUTO_STACK \
 -D_IMAGE_EXE_MAX=0 -o inicheck.com
gcc -g checksum.c -o checksum
