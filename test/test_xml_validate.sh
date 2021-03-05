#!/usr/bin/env bash
# Test for XML validations, Mainly Yang encoding
# Mainly negative checks, ie input correct but invalid XML and expect to get
# error message back.
# Triggered by the fact that clixon accepted duplicate containers.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xml:="clixon_util_xml -D $DBG"}

fyang=$dir/example.yang

cat <<EOF > $fyang
module example {
    yang-version 1.1;
    namespace "urn:example:example";
    prefix ex;
    revision 2019-01-13;
    container a{
        container b{
	  leaf c {
	    type string;
          }
        }
    }
}
EOF

new "xml unknown yang, fail"
echo "$clixon_util_xml -uy $fyang -vo"
expecteof "$clixon_util_xml -uy $fyang -vo" 0 '<a xmlns="urn:example:example"><xxx/></a>' 2> /dev/null

new "xml double containers no validation, ok"
expecteof "$clixon_util_xml -y $fyang -o" 0 '<a xmlns="urn:example:example"><b><c>x</c></b><b><c>y</c></b></a>' '^<a xmlns="urn:example:example"><b><c>x</c></b><b><c>y</c></b></a>$'

new "xml double containers validation, fail"
expecteof "$clixon_util_xml -y $fyang -vo" 255 '<a xmlns="urn:example:example"><b><c>x</c></b><b><c>y</c></b></a>' 2> /dev/null
#'xml validation error: protocol operation-failed' 

new "xml double leafs no validation, ok"
expecteof "$clixon_util_xml -y $fyang -o" 0 '<a xmlns="urn:example:example"><b><c>x</c><c>y</c></b></a>' '<a xmlns="urn:example:example"><b><c>x</c><c>y</c></b></a>'

new "xml double leafs validation, fail"
expecteof "$clixon_util_xml -y $fyang -vo" 255 '<a xmlns="urn:example:example"><b><c>x</c><c>y</c></b></a>' 2> /dev/null
#'xml validation error: protocol operation-failed'

rm -rf $dir

# unset conditional parameters 
unset clixon_util_xml

new "endtest"
endtest
