#!/bin/bash
# Parse yang openconfig tests
#PROG="valgrind --leak-check=full --show-leak-kinds=all ../util/clixon_util_yang"
PROG=../util/clixon_util_yang
OPENCONFIG=~/syssrc/openconfig

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


