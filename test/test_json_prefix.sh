#!/usr/bin/env bash
# Regression: a JSON member prefix longer than 255 bytes must be rejected
# without leaving the XML node without a name

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_json:=clixon_util_json}

# {"<256 x p>:a":1}
long_prefix(){
    awk 'BEGIN{
        printf "{\"";
        for (i = 0; i < 256; i++) printf "p";
        printf ":a\":1}";
    }'
}

new "test params"

new "json prefix: unprefixed member still parses"
expecteofx "$clixon_util_json" 0 '{"a":1}' "<a>1</a>"

new "json prefix: short prefix still parses"
expecteofx "$clixon_util_json" 0 '{"ex:a":1}' "<ex:a>1</ex:a>"

new "json prefix: prefix longer than 255 is rejected, not crashed"
expecteofx "$clixon_util_json" 255 "$(long_prefix)" ""

new "endtest"
endtest
