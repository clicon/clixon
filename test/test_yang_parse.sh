#!/bin/bash
# Test: YANG parser tests
# First an example yang, second all openconfig yangs
#PROG="valgrind --leak-check=full --show-leak-kinds=all ../util/clixon_util_yang"
PROG=../util/clixon_util_yang
OPENCONFIG=~/syssrc/openconfig

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
#expecteof "$PROG" 0 "$YANG" "^$YANG$"

if [ ! -d $OPENCONFIG ]; then
    echo "$OPENCONFIG not found. Do git clone https://github.com/openconfig/public and point DIR to it to run these tests"
    rm -rf $dir
    exit 0
fi

# Openconfig
new "Openconfig"
files=$(find $OPENCONFIG -name "*.yang")
for f in $files; do
    new "$f"
    YANG=$(cat $f)
 #   expecteof "$PROG" 0 "$YANG" "module"
done
rm -rf $dir


