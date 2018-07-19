#!/bin/bash
# Test: XML parser tests
PROG=../util/clixon_util_yang

# include err() and new() functions and creates $dir
. ./lib.sh

YANG=$(cat <<EOF
module test{
   prefix ex;
   extension c-define {
      description "Example from RFC 6020";
      argument "name";
   }
   ex:not-defined ARGUMENT;
}
EOF
)

new "yang parse"
expecteof $PROG 0 "$YANG" "^$YANG$"

rm -rf $dir

