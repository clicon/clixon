#!/bin/bash
# Test: JSON parser tests
#PROG="valgrind --leak-check=full --show-leak-kinds=all ../util/clixon_util_json"
PROG=../util/clixon_util_json

# include err() and new() functions and creates $dir
. ./lib.sh

new "json parse"
expecteof "$PROG" 0 '{"foo": -23}' "^<foo>-23</foo>$"

new "json parse list"
expecteof "$PROG" 0 '{"a":[0,1,2,3]}' "^<a>0</a><a>1</a><a>2</a><a>3</a>$"

rm -rf $dir
