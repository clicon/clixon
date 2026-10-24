#!/usr/bin/env bash
# Regression test for the XPath parser's recursion-depth guard
# (XPATH_PARSE_MAX_DEPTH in lib/src/clixon_xpath_parse.y, xp_new()).

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xpath:=clixon_util_xpath}

xml=$dir/xml.xml

cat <<EOF > $xml
<a/>
EOF

# Helper: print "1+1+1+...+1" with $1 '+1' repeats (depth roughly $1+small-const)
chain(){
    awk -v n="$1" 'BEGIN{
        printf "1";
        for (i = 0; i < n; i++) printf "+1";
    }'
}
# Helper: print "/a/a/.../a" with $1 steps
longpath(){
    awk -v n="$1" 'BEGIN{
        for (i = 0; i < n; i++) printf "/a";
    }'
}
# Helper: print "a[1][1]...[1]" with $1 predicates
manypred(){
    awk -v n="$1" 'BEGIN{
        printf "a";
        for (i = 0; i < n; i++) printf "[1]";
    }'
}

new "test params: -f $xml"

new "xpath depth: shallow operator chain still works (sanity)"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p "$(chain 3)")" 0 "number:4"

new "xpath depth: deep-but-legitimate operator chain (500 levels) still works"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p "$(chain 500)")" 0 "number:501"

new "xpath depth: pathological operator chain (1100 levels) is rejected, not crashed"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -l o -p "$(chain 1100)")" 255 "too deeply nested"

new "xpath depth: pathological relative path (1100 steps) is rejected, not crashed"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -l o -p "$(longpath 1100)")" 255 "too deeply nested"

new "xpath depth: pathological predicate repetition (1100 predicates) is rejected, not crashed"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -l o -p "$(manypred 1100)")" 255 "too deeply nested"

rm -rf $dir

new "endtest"
endtest
