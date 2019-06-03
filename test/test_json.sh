#!/bin/bash
# Test: JSON parser tests
# Note that members should not be quoted. See test_restconf2.sh for typed
#PROG="valgrind --leak-check=full --show-leak-kinds=all ../util/clixon_util_json"
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_json:=clixon_util_json}

new "json parse to xml"
expecteofx "$clixon_util_json" 0 '{"foo": -23}' "<foo>-23</foo>"

new "json parse to json" # should be {"foo": -23}
expecteofx "$clixon_util_json -j" 0 '{"foo": -23}' '{"foo": "-23"}'

new "json parse list xml"
expecteofx "$clixon_util_json" 0 '{"a":[0,1,2,3]}' "<a>0</a><a>1</a><a>2</a><a>3</a>"

new "json parse list json" # should be {"a":[0,1,2,3]}
expecteofx "$clixon_util_json -j" 0 '{"a":[0,1,2,3]}' '{"a": "0"}{"a": "1"}{"a": "2"}{"a": "3"}'

fyang=$dir/json.yang
fjson=$dir/json.json
cat <<EOF > $fyang
module json{
   prefix ex;
   namespace "urn:example:clixon";
   leaf a{
     type int32;
   }
   container c{
     leaf a{
       type int32;
     }
     leaf s{
       type string;
     }
   }
}
EOF

JSON='{"json:a": -23}'

new "json leaf back to json"
expecteofx "$clixon_util_json -j -y $fyang" 0 "$JSON" "$JSON"

JSON='{"json:c": {"a": 937}}'
new "json parse container back to json"
expecteofx "$clixon_util_json -j -y $fyang" 0 "$JSON" "$JSON"

# This is wrong
if false; then
JSON='{"json:c": {"s": "<![CDATA[  z > x  & x < y ]]>"}}'
new "json parse cdata xml"
expecteofx "$clixon_util_json -j -y $fyang" 0 "$JSON" "$JSON"
fi

rm -rf $dir
