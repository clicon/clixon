#!/usr/bin/env bash
# Instance-id tests with multiple results
# RFC 7950 Sections 9.13 and 14 says that:
#   Predicates are used only for specifying the values for the key nodes for list entries
# but does not explicitly say that list nodes can skip them
# And in RFC8341 node-instance-identifiers are defined as:
#   All the same rules as an instance-identifier apply, except that predicates for keys are optional.
#   If a key predicate is missing, then the node-instance-identifier represents all possible server
#   instances for that key.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_path:=clixon_util_path -D $DBG}

xml1=$dir/xml1.xml
ydir=$dir/yang

if [ ! -d $ydir ]; then
    mkdir $ydir
fi

# Nested lists
cat <<EOF > $ydir/example.yang
module example{
  yang-version 1.1;
  namespace "urn:example:id";
  prefix ex;
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      container next{
        list parameter{
          key name;
          leaf name{
            type string;
          }
          leaf value{
            type string;
          }
        }
      }
    }
  }
}
EOF

cat <<EOF > $xml1
<table xmlns="urn:example:id">
     <parameter>
       <name>a</name>
       <next>
         <parameter>
           <name>a</name>
           <value>11</value>
         </parameter>
         <parameter>
           <name>b</name>
           <value>22</value>
         </parameter>
       </next>
     </parameter>
     <parameter>
       <name>b</name>
       <next>
         <parameter>
           <name>a</name>
           <value>33</value>
         </parameter>
       </next>
     </parameter>
</table>
EOF

new "instance-id top-level param"
expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /ex:table/ex:parameter)" 0 "0: <parameter><name>a</name><next><parameter><name>a</name><value>11</value></parameter><parameter><name>b</name><value>22</value></parameter></next></parameter>" "1: <parameter><name>b</name><next><parameter><name>a</name><value>33</value></parameter></next></parameter>"

new "instance-id a/next"
expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /ex:table/ex:parameter[ex:name=\"a\"]/ex:next)" 0 "0: <next><parameter><name>a</name><value>11</value></parameter><parameter><name>b</name><value>22</value></parameter></next>"

new "instance-id a/next/param"
expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /ex:table/ex:parameter[ex:name=\"a\"]/ex:next/ex:parameter)" 0 "0: <parameter><name>a</name><value>11</value></parameter>" "1: <parameter><name>b</name><value>22</value></parameter>"

new "instance-id a/next/param/a"
expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /ex:table/ex:parameter[ex:name=\"a\"]/ex:next/ex:parameter[ex:name=\"a\"])" 0 "0: <parameter><name>a</name><value>11</value></parameter>" "0: <parameter><name>a</name><value>11</value></parameter>"

new "instance-id a/next/param/a/value"
expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /ex:table/ex:parameter[ex:name=\"a\"]/ex:next/ex:parameter[ex:name=\"a\"]/ex:value)" 0 "0: <value>11</value>"

new "instance-id top-level parameter/next"
expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /ex:table/ex:parameter/ex:next)" 0 "0: <next><parameter><name>a</name><value>11</value></parameter><parameter><name>b</name><value>22</value></parameter></next>" "1: <next><parameter><name>a</name><value>33</value></parameter></next>"

new "instance-id top-level parameter/next/parameter"
expectpart "$($clixon_util_path -f $xml1 -y $ydir -p /ex:table/ex:parameter/ex:next/ex:parameter)" 0 "0: <parameter><name>a</name><value>11</value></parameter>" "1: <parameter><name>b</name><value>22</value></parameter>" "2: <parameter><name>a</name><value>33</value></parameter>"

rm -rf $dir
unset clixon_util_path # for other script reusing it


