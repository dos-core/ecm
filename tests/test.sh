#! /bin/bash

echo -ne "" > test2.lst
nasm test2.asm -l test2.lst
cat test2.lst
cat test2.map

