#!/usr/bin/env bash
# Test: TEX syntax parser tests. 

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_text_syntax:=clixon_util_text_syntax}
: ${clixon_util_xml:=clixon_util_xml}

fyang=$dir/example.yang

cat <<EOF > $fyang
module example{
   prefix ex;
   namespace "urn:example:clixon";
    /* Generic config data */
   container table{
      list parameter{
         key "name index";
	 leaf name{
	    type string;
	 }
	 leaf index{
	    type int32;
	 }
	 leaf value{
	    type string;
	 }
	 leaf-list array{
	    type string;
         }
      }
   }
}
EOF

cat <<EOF > $dir/x1.xml
<table xmlns="urn:example:clixon">
   <parameter>
      <name>a</name>
      <index>0</index>
      <value>foo bar\n
             description</value>
   </parameter>
   <parameter>
      <name>b</name>
      <index>17</index>
      <value>bar:fie</value>
      <array>bar</array>
      <array>fie</array>
      <array>foo</array>
   </parameter>
</table>
EOF

cat <<EOF > $dir/x1.txt
example:table {
    parameter {
        name a;
        index 0;
        value "foo bar\n
             description";
    }
    parameter {
        name b;
        index 17;
        value bar:fie;
        array [
            bar
            fie
            foo
       ]
    }
}
EOF

new "test params: -y $fyang"

# No yang
new "xml to txt"
expectpart "$($clixon_util_xml -f $dir/x1.xml -y $fyang -oX -D $DBG > $dir/x2.txt)" 0 ""

ret=$(diff $dir/x1.txt $dir/x2.txt)
if [ $? -ne 0 ]; then
    err1 "$ret" 
fi

new "txt to xml"
expectpart "$($clixon_util_text_syntax -f $dir/x1.txt -y $fyang -D $DBG > $dir/x2.xml)" 0 ""

ret=$(diff $dir/x1.xml $dir/x2.xml)
if [ $? -ne 0 ]; then
    err1 "XML" "$ret"
fi

rm -rf $dir

# unset conditional parameters 
unset clixon_util_text_syntax
unset clixon_util_xml

new "endtest"
endtest
