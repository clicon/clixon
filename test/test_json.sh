#!/bin/bash
# Test: JSON parser tests
# Note that nmbers shouldnot be quoted. See test_restconf2.sh for typed
#PROG="valgrind --leak-check=full --show-leak-kinds=all ../util/clixon_util_json"
PROG=../util/clixon_util_json

# include err() and new() functions and creates $dir
. ./lib.sh

new "json parse to xml"
expecteofx "$PROG" 0 '{"foo": -23}' "<foo>-23</foo>"

new "json parse to json" # should be {"foo": -23}
expecteofx "$PROG -j" 0 '{"foo": -23}' '{"foo": "-23"}'

new "json parse list xml"
expecteofx "$PROG" 0 '{"a":[0,1,2,3]}' "<a>0</a><a>1</a><a>2</a><a>3</a>"

new "json parse list json" # should be {"a":[0,1,2,3]}
expecteofx "$PROG -j" 0 '{"a":[0,1,2,3]}' '{"a": "0"}{"a": "1"}{"a": "2"}{"a": "3"}'

rm -rf $dir
