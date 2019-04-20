#! /bin/bash

echo -ne "" > "$1.lst"
nasm -I ../ "$1.asm" -D_MAP="'$1.map'" -l "$1.lst" -f bin -o "$@"
cat "$1.lst"
ndisasm "$1"

