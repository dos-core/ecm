#! /bin/bash

echo -ne "" > test.lst
nasm test.asm -l test.lst
cat test.lst
cat test.map

