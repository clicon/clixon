#!/usr/bin/env bash
# Test: JSON empty/null values. See RFC7951
# tests include:
# - parsing in XML, output in JSON
# - parsing in JSON, output in JSON
# - parsing in JSON, output in XML?
#
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_json:=clixon_util_json}
: ${clixon_util_xml:=clixon_util_xml}

fyang=$dir/json.yang
cat <<EOF > $fyang
module json{
   prefix j;
   namespace "urn:example:clixon";
   container leafs{
     leaf a{
       type int32;
     }
     leaf b{
       type string;
     }
     leaf c{
       type boolean;
     }
     leaf d{
       type empty;
     }
   }
   container leaf-lists{
     leaf-list a{
       type empty;
     }
     leaf-list b{
       type string;
     }
   }
   container containers{
     presence true;
     container a{
     presence true;
       leaf b {
         type empty;
       }
     }
   }
   container anys{
     anydata a;
     anyxml b;
   }
}
EOF

new "test params: -y $fyang"

# Leafs        
XML='<leafs xmlns="urn:example:clixon"><a>0</a><b></b><c>false</c><d></d></leafs>'
JSON='{"json:leafs":{"a":0,"b":"","c":false,"d":[null]}}'

new "leafs xml to json"
expecteofx "$clixon_util_xml -ovjy $fyang" 0 "$XML" "$JSON"

new "leafs json to json"
expecteofx "$clixon_util_xml -ovJjy $fyang" 0 "$JSON" "$JSON" 

new "leafs json to xml"
expecteofx "$clixon_util_xml -ovJy $fyang" 0 "$JSON" "$XML"

# Leaf-lists single
XML='<leaf-lists xmlns="urn:example:clixon"><a></a><b></b></leaf-lists>'
JSON='{"json:leaf-lists":{"a":[[null]],"b":[""]}}'

new "leaf-list single xml to json"
expecteofx "$clixon_util_xml -ovjy $fyang" 0 "$XML" "$JSON"

new "leaf-list single json to json"
expecteofx "$clixon_util_xml -ovjJy $fyang" 0 "$JSON" "$JSON"

new "leaf-list single json to xml"
expecteofx "$clixon_util_xml -ovJy $fyang" 0 "$JSON" "$XML"

# Leaf-lists multiple
XML='<leaf-lists xmlns="urn:example:clixon"><a></a><a></a><b></b><b></b><b>null</b></leaf-lists>'
JSON='{"json:leaf-lists":{"a":[[null],[null]],"b":["","","null"]}}'

new "leaf-list multiple xml to json"
expecteofx "$clixon_util_xml -ovjy $fyang" 0 "$XML" "$JSON"

new "leaf-list multiple json to json"
expecteofx "$clixon_util_xml -ovjJy $fyang" 0 "$JSON" "$JSON"

new "leaf-list multiple json to xml"
expecteofx "$clixon_util_xml -ovJy $fyang" 0 "$JSON" "$XML"

# Empty container
XML='<containers xmlns="urn:example:clixon"><a/></containers>'
JSON='{"json:containers":{"a":{}}}'

new "empty container xml to json"
expecteofx "$clixon_util_xml -ovjy $fyang" 0 "$XML" "$JSON"

new "empty container json to json"
expecteofx "$clixon_util_xml -ovjJy $fyang" 0 "$JSON" "$JSON"

new "empty container json to xml"
expecteofx "$clixon_util_xml -ovJy $fyang" 0 "$JSON" "$XML"

# Empty container whitespace
XML='<containers xmlns="urn:example:clixon"><a> </a></containers>'
JSON='{"json:containers":{"a":{}}}'

new "empty container whitespace xml to json"
expecteofx "$clixon_util_xml -ovjy $fyang" 0 "$XML" "$JSON"

# container empty leaf
XML='<containers xmlns="urn:example:clixon"><a><b></b></a></containers>'
JSON='{"json:containers":{"a":{"b":[null]}}}'

new "container empty leaf xml to json"
expecteofx "$clixon_util_xml -ovjy $fyang" 0 "$XML" "$JSON"

new "container empty leaf json to json"
expecteofx "$clixon_util_xml -ovjJy $fyang" 0 "$JSON" "$JSON"

new "container empty leaf json to xml"
expecteofx "$clixon_util_xml -ovJy $fyang" 0 "$JSON" "$XML"

# anydata
# An anydata instance is encoded in the same way as a container, as a name/object pair
XML='<anys xmlns="urn:example:clixon"><a/></anys>'
JSON='{"json:anys":{"a":{}}}'

new "anydata xml to json"
expecteofx "$clixon_util_xml -ovjy $fyang" 0 "$XML" "$JSON"

new "anydata json to json"
expecteofx "$clixon_util_xml -ovjJy $fyang" 0 "$JSON" "$JSON"

new "anydata json to xml"
expecteofx "$clixon_util_xml -ovJy $fyang" 0 "$JSON" "$XML"

# anydata
XML='<anys xmlns="urn:example:clixon"><a><c/><d/></a></anys>'
JSON='{"json:anys":{"a":{"c":{},"d":{}}}}'

new "anydata w empty node xml to json"
expecteofx "$clixon_util_xml -ovjy $fyang" 0 "$XML" "$JSON"

new "anydata w empty node json to json"
expecteofx "$clixon_util_xml -ovjJy $fyang" 0 "$JSON" "$JSON"

new "anydata w empty node json to xml"
expecteofx "$clixon_util_xml -ovJy $fyang" 0 "$JSON" "$XML"

# Anyxml
XML='<anys xmlns="urn:example:clixon"><b/></anys>'
JSON='{"json:anys":{"b":{}}}'

new "anyxml xml to json"
expecteofx "$clixon_util_xml -ovjy $fyang" 0 "$XML" "$JSON"

new "anyxml json to json"
expecteofx "$clixon_util_xml -ovjJy $fyang" 0 "$JSON" "$JSON"

new "anyxml json to xml"
expecteofx "$clixon_util_xml -ovJy $fyang" 0 "$JSON" "$XML" 

# JSON wrong in?
# XXX: maybe this should give error?
JSON='{"json:leafs":{"b":null}}'
JSON2='{"json:leafs":{"b":""}}'
new "leafs null in json to json"
expecteofx "$clixon_util_xml -ovJjy $fyang" 0 "$JSON" "$JSON2"

# XXX: maybe this should give error?
JSON='{"json:leafs":{"b":[null]}}'
JSON2='{"json:leafs":{"b":""}}'
new "leafs [null] in json to json"
expecteofx "$clixon_util_xml -ovJjy $fyang" 0 "$JSON" "$JSON2"

# XXX: maybe this should give error?
JSON='{"json:leafs":{"d":null}}'
JSON2='{"json:leafs":{"d":[null]}}'
new "leafs null in json to json"
expecteofx "$clixon_util_xml -ovJjy $fyang" 0 "$JSON" "$JSON2"

JSON='{"json:leafs":{"d":""}}'
JSON2='{"json:leafs":{"d":[null]}}'
new "leafs \"\" in json to json should give error"
expecteofx "$clixon_util_xml -ovJjy $fyang" 255 "$JSON" "" 2> /dev/null

rm -rf $dir

# unset conditional parameters 
unset clixon_util_json
unset clixon_util_xml

new "endtest"
endtest
