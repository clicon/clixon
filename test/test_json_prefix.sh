#!/usr/bin/env bash
# Regression: a JSON member prefix longer than 255 bytes must be rejected
# without leaving the XML node without a name

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_json:=clixon_util_json}

# JSON prefixes are module names (RFC 7951), not XML prefixes
fyang=$dir/json.yang
cat <<EOF > $fyang
module ex{
   prefix ex;
   namespace "urn:example:ex";
   leaf a{
      type int32;
   }
}
EOF

# {"<256 x p>:a":1}
long_prefix(){
    awk 'BEGIN{
        printf "{\"";
        for (i = 0; i < 256; i++) printf "p";
        printf ":a\":1}";
    }'
}

new "test params: -y $fyang"

new "json prefix: unprefixed member still parses"
expecteofx "$clixon_util_json" 0 '{"a":1}' "<a>1</a>"

new "json prefix: module prefix still parses"
expecteofx "$clixon_util_json -y $fyang" 0 '{"ex:a":1}' '<a xmlns="urn:example:ex">1</a>'

new "json prefix: prefix longer than 255 is rejected, not crashed"
expecteofx "$clixon_util_json" 255 "$(long_prefix)" ""

rm -rf $dir

new "endtest"
endtest
