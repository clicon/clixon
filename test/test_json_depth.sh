#!/usr/bin/env bash
# Regression test pinning JSON's existing protection against unbounded
# parser recursion
# Deeply nested JSON should hit bison's generic YYMAXDEPTH stack-growth limit

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_json:=clixon_util_json}

# Helper: nested JSON object "{"a":{"a":...1...}}" with $1 levels
deep_obj(){
    awk -v n="$1" 'BEGIN{
        for (i = 0; i < n; i++) printf "{\"a\":";
        printf "1";
        for (i = 0; i < n; i++) printf "}";
    }'
}
# Helper: nested JSON array "[[[...1...]]]" with $1 levels
deep_arr(){
    awk -v n="$1" 'BEGIN{
        for (i = 0; i < n; i++) printf "[";
        printf "1";
        for (i = 0; i < n; i++) printf "]";
    }'
}
# Helper: expected XML for deep_obj($1)
deep_obj_xml(){
    awk -v n="$1" 'BEGIN{
        for (i = 0; i < n; i++) printf "<a>";
        printf "1";
        for (i = 0; i < n; i++) printf "</a>";
    }'
}

new "test params"

new "json depth: shallow nested object still works (sanity)"
expecteofx "$clixon_util_json" 0 "$(deep_obj 3)" "$(deep_obj_xml 3)"

new "json depth: deep-but-legitimate nested object (100 levels) still works"
expecteofx "$clixon_util_json" 0 "$(deep_obj 100)" "$(deep_obj_xml 100)"

new "json depth: pathological nested object (50000 levels) is cleanly rejected, not crashed"
expecteofx "$clixon_util_json" 255 "$(deep_obj 50000)" ""

new "json depth: pathological nested array (50000 levels) is cleanly rejected, not crashed"
expecteofx "$clixon_util_json" 255 "$(deep_arr 50000)" ""

new "endtest"
endtest
