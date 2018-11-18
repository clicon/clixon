#!/bin/bash
# Test: YANG parser tests
# First an example yang, second all openconfig yangs
# Problem with this is that util only parses single file. it should
# call yang_parse().
#PROG="valgrind --leak-check=full --show-leak-kinds=all ../util/clixon_util_yang"
PROG=../util/clixon_util_yang
OPENCONFIG=~/syssrc/openconfig
exit 0 # nyi
# include err() and new() functions and creates $dir
. ./lib.sh

# Openconfig
# Files not parseable:
# - openconfig-access-points.yang
# - openconfig-access-points.yang
new "Openconfig"
files=$(find $OPENCONFIG -name "*.yang")
for f in $files; do
    new "$f"
    YANG=$(cat $f)
 # NYI
  expecteof "$PROG" 0 "$YANG" "module"
done
rm -rf $dir


