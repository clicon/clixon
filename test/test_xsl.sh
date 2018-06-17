#!/bin/bash
# Test: XSL tests
PROG=../lib/src/clixon_util_xsl

# include err() and new() functions and creates $dir
. ./lib.sh

new "xsl test"
expecteof $PROG 0 "a
<a><b/></a>" "^0:<a><b/></a>$"

rm -rf $dir
