#!/usr/bin/env bash
# Regression test pinning YANG's existing protection against unbounded parser
# recursion
# Deeply nested YANG already hits bison's generic YYMAXDEPTH stack-growth limit
#
# The grammar's one genuinely left-recursive construct, qstrings: qstrings
# '+' qstring reduces into a flat realloc'd buffer rather#

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_yang:=clixon_util_yang}

# Helper: YANG module with $1 levels of nested "container a { ... }" around a leaf
deep_yang(){
    awk -v n="$1" 'BEGIN{
        printf "module m { namespace \"urn:m\"; prefix m;\n";
        for (i = 0; i < n; i++) printf "container a {\n";
        printf "leaf x { type string; }\n";
        for (i = 0; i < n; i++) printf "}\n";
        printf "}\n";
    }'
}
# Helper: expected clixon_util_yang pretty-print output for deep_yang($1)
deep_yang_out(){
    awk -v n="$1" '
    function indent(c){ for (j = 0; j < c; j++) printf " "; }
    BEGIN{
        print "yang-specification data {";
        print "   module m {";
        print "      namespace urn:m;";
        print "      prefix m;";
        for (i = 0; i < n; i++){
            indent(6+3*i); print "container a {";
        }
        indent(6+3*n); print "leaf x {";
        indent(6+3*n+3); print "type string;";
        indent(6+3*n); print "}";
        for (i = n-1; i >= 0; i--){
            indent(6+3*i); print "}";
        }
        print "   }";
        print "}";
    }'
}

new "test params"

new "yang depth: shallow nested container still works (sanity)"
expecteofx "$clixon_util_yang" 0 "$(deep_yang 3)" "$(deep_yang_out 3)"

new "yang depth: deep-but-legitimate nested container (100 levels) still works"
expecteofx "$clixon_util_yang" 0 "$(deep_yang 100)" "$(deep_yang_out 100)"

new "yang depth: pathological nested container (50000 levels) is cleanly rejected, not crashed"
expecteofx "$clixon_util_yang" 255 "$(deep_yang 50000)" ""

new "endtest"
endtest
