#! /bin/bash

nasm -I ../../lmacros/ test.asm -o test.big \
&& nasm -I ../../lmacros/ mzshim.asm -D_FILE="'test.big'" \
 -D_IMAGE_EXE_IP=256 -D_IMAGE_EXE_AUTO_STACK \
 -D_IMAGE_EXE_MIN_CALC=_IMAGE_EXE_AUTO_STACK \
 -D_IMAGE_EXE_MAX=0 -o test.com
