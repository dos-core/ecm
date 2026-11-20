#! /bin/bash

# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

[ -z "$NASM" ] && NASM=nasm

"$NASM" -D_LARGE=0 -I ../lmacros/ testpl.asm -o testpl.bin -l testpl.lst "$@" &&
  "$NASM" -I ../lmacros/ -I ./ -I ../scanptab/ \
  -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK \
  -D_IMAGE_EXE_MIN_CALC=_IMAGE_EXE_AUTO_STACK \
  -D_IMAGE_EXE_MAX=0 -D_PAYLOAD_FILE='"testpl.bin"' \
  -D_INILOAD_SIGNATURE='"TP"' iniload.asm -o testpl.com -l testpli.lst \
  "$@"

"$NASM" -I ../lmacros/ testboot.asm -o testboot.bin -l testboot.lst "$@"
