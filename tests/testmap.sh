#! /bin/bash

echo -ne "" > "$1.lst"
nasm "$1.asm" -D_MAP="$1.map" -l "$1.lst" -f bin -o "$@" -I ../
cat "$1.lst"
ndisasm "$1"

