#!/bin/bash
# Test: YANG parser tests
#PROG="valgrind --leak-check=full --show-leak-kinds=all ../util/clixon_util_yang"
PROG=../util/clixon_util_yang

# include err() and new() functions and creates $dir
. ./lib.sh

rm -rf $dir


