#!/usr/bin/env bash
# Test: XML performance test 
# See https://github.com/clicon/clixon/issues/96
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xml:="clixon_util_xml"}

# Number of list/leaf-list entries in file
: ${perfnr:=30000}

fxml=$dir/long.xml

new "generate long file $fxml"
echo -n "<rpc-reply><stdout><![CDATA[" > $fxml
for (( i=0; i<$perfnr; i++ )); do  
    echo "*>i10.0.0.$i/32     10.255.0.20              0    100      0 i" >> $fxml
done
echo "]]></stdout></rpc-reply>" >> $fxml

new "xml parse long CDATA"
expecteof_file "time $clixon_util_xml" 0 "$fxml"
      
rm -rf $dir

