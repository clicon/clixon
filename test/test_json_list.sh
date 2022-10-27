#!/usr/bin/env bash
# Test: JSON (leaf-)list and YANG. See RFC7951 sec 5.3 / 5.4

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_json:=clixon_util_json}
: ${clixon_util_xml:=clixon_util_xml}

fyang=$dir/json.yang
cat <<EOF > $fyang
module json{
   prefix ex;
   namespace "urn:example:clixon";
   container c{
      leaf-list l1{
         type int32;
      }
      list l2{
         key name;
         leaf name{
            type int32;
         }
         leaf value{
            type string;
         }
      }
      leaf extra{
         type string;
      }
   }
   leaf-list l1{
      description "top-level";
      type int32;
   }
   list l2{
      description "top-level";
      key name;
      leaf name{
         type int32;
      }
      leaf value{
         type string;
      }
   }
}
EOF

# JSON list input/output tests auth test with arguments:
# 1. test name
# 2. JSON
# 3. XML
function testrun()
{
    test=$1
    json=$2  
    xml=$3

    new "$test json in/out"
    expecteofx "$clixon_util_json -jy $fyang -D $DBG" 0 "$json" "$json"

    new "$test json in / xml out"
    expecteofx "$clixon_util_json -y $fyang -D $DBG" 0  "$json" "$xml"

    new "$test xml in / json out"
    expecteofx "$clixon_util_xml -ojvy $fyang -D $DBG" 0 "$xml" "$json"
}

new "test params: -y $fyang"

testrun "top one leaf-list" '{"json:l1":[1]}' '<l1 xmlns="urn:example:clixon">1</l1>'


#testrun "top two leaf-list" '{"json:l1":[1,2]}' '<l1 xmlns="urn:example:clixon">1</l1><l1 xmlns="urn:example:clixon">2</l1>'

testrun "one leaf-list" '{"json:c":{"l1":[1]}}' '<c xmlns="urn:example:clixon"><l1>1</l1></c>'

testrun "two leaf-list" '{"json:c":{"l1":[1,2]}}' '<c xmlns="urn:example:clixon"><l1>1</l1><l1>2</l1></c>'

testrun "three leaf-list" '{"json:c":{"l1":[1,2,3]}}' '<c xmlns="urn:example:clixon"><l1>1</l1><l1>2</l1><l1>3</l1></c>'

testrun "multiple leaf-list" '{"json:c":{"l1":[1,2],"extra":"abc"}}' '<c xmlns="urn:example:clixon"><l1>1</l1><l1>2</l1><extra>abc</extra></c>'

testrun "top one list" '{"json:l2":[{"name":1,"value":"x"}]}' '<l2 xmlns="urn:example:clixon"><name>1</name><value>x</value></l2>'

# XXX
#testrun "top two list" '{"json:l2":[{"name":1,"value":"x"},{"name":2,"value":"x"}]}' '<l2 xmlns="urn:example:clixon"><name>1</name><value>x</value></l2><l2 xmlns="urn:example:clixon"><name>2</name><value>x</value></l2>'

testrun "one list" '{"json:c":{"l2":[{"name":1,"value":"x"}]}}' '<c xmlns="urn:example:clixon"><l2><name>1</name><value>x</value></l2></c>'

testrun "two list" '{"json:c":{"l2":[{"name":1,"value":"x"},{"name":2,"value":"y"}]}}' '<c xmlns="urn:example:clixon"><l2><name>1</name><value>x</value></l2><l2><name>2</name><value>y</value></l2></c>'

testrun "three list" '{"json:c":{"l2":[{"name":1,"value":"x"},{"name":2,"value":"y"},{"name":3,"value":"z"}]}}' '<c xmlns="urn:example:clixon"><l2><name>1</name><value>x</value></l2><l2><name>2</name><value>y</value></l2><l2><name>3</name><value>z</value></l2></c>'

rm -rf $dir

# unset conditional parameters 
unset clixon_util_json
unset clixon_util_xml

new "endtest"
endtest
