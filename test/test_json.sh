#!/usr/bin/env bash
# Test: JSON parser tests. See RFC7951
# - Multi-line + pretty-print 
# - Empty values
# Note that members should not be quoted. See test_restconf2.sh for typed
#PROG="valgrind --leak-check=full --show-leak-kinds=all ../util/clixon_util_json"
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_json:=clixon_util_json}
: ${clixon_util_xml:=clixon_util_xml}

fyang=$dir/json.yang
cat <<EOF > $fyang
module json{
   prefix ex;
   namespace "urn:example:clixon";
   identity genre {
      description
        "From RFC8040 jukebox example. 
         Identity prefixes are translated from module-name to xml prefix";
   }
   identity blues {
      base genre;
   }
   typedef gtype{
      type identityref{
         base genre;
      }
   }
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
   leaf g1 {
      description "direct type";
      type identityref { base genre; }
   }
   leaf g2 {
      description "indirect type";
      type gtype;
   }
}
EOF

new "test params: -y $fyang"

# No yang
new "json parse to xml"
expecteofx "$clixon_util_json" 0 '{"foo": -23}' "<foo>-23</foo>"

new "json parse to json" # should be {"foo": -23}
expecteofx "$clixon_util_json -j" 0 '{"foo": -23}' '{"foo":"-23"}'

new "json parse list to xml"
expecteofx "$clixon_util_json" 0 '{"a":[0,1,2,3]}' "<a>0</a><a>1</a><a>2</a><a>3</a>"

# See test_restconf.sh
new "json parse empty list to xml"
expecteofx "$clixon_util_json" 0 '{"a":[]}' "<a/>"

new "json parse list json" # should be {"a":[0,1,2,3]}
expecteofx "$clixon_util_json -j" 0 '{"a":[0,1,2,3]}' '{"a":"0"}{"a":"1"}{"a":"2"}{"a":"3"}'

# Multi-line JSON not pretty-print
JSON='{"json:c":{"a":42,"s":"string"}}'
# Same with pretty-print
JSONP='{
  "json:c": {
    "a": 42,
    "s": "string"
  }
}'

new "json no pp in/out"
expecteofx "$clixon_util_json -jy $fyang" 0 "$JSON" "$JSON"

new "json pp in/out"
expecteofeq "$clixon_util_json -jpy $fyang" 0 "$JSONP" "$JSONP"

new "json pp in/ no pp out"
expecteofeq "$clixon_util_json -jy $fyang" 0 "$JSONP" "$JSON"

new "json no pp in/ pp out"
expecteofeq "$clixon_util_json -jpy $fyang" 0 "$JSON" "$JSONP"

JSON='{"json:a":-23}'

new "json leaf back to json"
expecteofx "$clixon_util_json -jy $fyang" 0 "$JSON" "$JSON"

JSON='{"json:c":{"a":937}}'
new "json parse container back to json"
expecteofx "$clixon_util_json -jy $fyang" 0 "$JSON" "$JSON"

# identities translation json -> xml is tricky wrt prefixes, json uses module
# name, xml uses xml namespace prefixes (or default)
JSON='{"json:g1":"json:blues"}'

new "json identity to xml"
expecteofx "$clixon_util_json -y $fyang" 0 "$JSON" '<g1 xmlns="urn:example:clixon">blues</g1>'

new "json identity back to json"
expecteofx "$clixon_util_json -jy $fyang" 0 "$JSON" '{"json:g1":"blues"}'

new "xml identity with explicit ns to json"
expecteofx "$clixon_util_xml -ovjy $fyang" 0 '<g1 xmlns="urn:example:clixon" xmlns:ex="urn:example:clixon">ex:blues</g1>' '{"json:g1":"blues"}'

# Same with indirect type
JSON='{"json:g2":"json:blues"}'

new "json indirect identity to xml"
expecteofx "$clixon_util_json -y $fyang" 0 "$JSON" '<g2 xmlns="urn:example:clixon">blues</g2>'

new "json indirect identity back to json"
expecteofx "$clixon_util_json -jy $fyang" 0 "$JSON" '{"json:g2":"blues"}'

new "xml indirect identity with explicit ns to json"
expecteofx "$clixon_util_xml -ojvy $fyang" 0 '<g2 xmlns="urn:example:clixon" xmlns:ex="urn:example:clixon">ex:blues</g2>' '{"json:g2":"blues"}'

# See https://github.com/clicon/clixon/issues/236
JSON='{"data": {"a": [],"b": [{"name": 17},{"name": 42},{"name": 99}]}}'
new "empty list followed by list"
expecteofx "$clixon_util_json" 0 "$JSON" "<data><a/><b><name>17</name></b><b><name>42</name></b><b><name>99</name></b></data>"

JSON='{"data": {"a": [],"b": [{"name": 17},{"name": []},{"name": 99}]}}'
new "empty list followed by list again empty"
expecteofx "$clixon_util_json" 0 "$JSON" "<data><a/><b><name>17</name></b><b><name/></b><b><name>99</name></b></data>"

JSON='{"json:c":{"s":"<![CDATA[  z > x  & x < y ]]>"}}'
new "json parse cdata xml"
expecteofx "$clixon_util_json -j -y $fyang" 0 "$JSON" "$JSON"

rm -rf $dir

# unset conditional parameters 
unset clixon_util_json
unset clixon_util_xml

new "endtest"
endtest
