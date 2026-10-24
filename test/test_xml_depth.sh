#!/usr/bin/env bash
# Regression test pinning XML's existing protection against unbounded parser
# recursion
# Deeply nested XML already hits bison's generic YYMAXDEPTH stack-growth limit

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xml:="clixon_util_xml"}

# Helper: nested XML "<a><a>...1...</a></a>" with $1 levels
deep_xml(){
    awk -v n="$1" 'BEGIN{
        for (i = 0; i < n; i++) printf "<a>";
        printf "1";
        for (i = 0; i < n; i++) printf "</a>";
    }'
}

new "test params"

new "xml depth: shallow nesting still works (sanity)"
expecteofx "$clixon_util_xml -o" 0 "$(deep_xml 3)" "$(deep_xml 3)"

new "xml depth: deep-but-legitimate nesting (100 levels) still works"
expecteofx "$clixon_util_xml -o" 0 "$(deep_xml 100)" "$(deep_xml 100)"

new "xml depth: pathologically deep nesting (50000 levels) is cleanly rejected, not crashed"
expecteofx "$clixon_util_xml -o" 255 "$(deep_xml 50000)" ""

new "endtest"
endtest
