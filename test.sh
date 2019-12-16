#! /bin/bash
./test
dosemu -K "$PWD" -E test.com -dumb -quiet
./test2
