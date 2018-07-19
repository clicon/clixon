#!/bin/bash
# Test: XML parser tests
PROG=../util/clixon_util_xml

# include err() and new() functions and creates $dir
. ./lib.sh

new "xml parse"
expecteof $PROG 0 "<a><b/></a>" "^<a><b/></a>$"

XML=$(cat <<EOF
<a><description>An example of escaped CENDs</description>
<sometext>
<![CDATA[ They're saying "x < y" & that "z > y" so I guess that means that z > x ]]>
</sometext>
<!-- This text contains a CEND ]]> -->
<!-- In this first case we put the ]] at the end of the first CDATA block
     and the > in the second CDATA block -->
<data><![CDATA[This text contains a CEND ]]]]><![CDATA[>]]></data>
<!-- In this second case we put a ] at the end of the first CDATA block
     and the ]> in the second CDATA block -->
<alternative><![CDATA[This text contains a CEND ]]]><![CDATA[]>]]></alternative>
</a>
EOF
)
new "xml CDATA"
expecteof $PROG 0 "$XML" "^<a><description>An example of escaped CENDs</description><sometext>
<![CDATA[ They're saying \"x < y\" & that \"z > y\" so I guess that means that z > x ]]>
</sometext><data><![CDATA[This text contains a CEND ]]]]><![CDATA[>]]></data><alternative><![CDATA[This text contains a CEND ]]]><![CDATA[]>]]></alternative></a>$"

XML=$(cat <<EOF
<message>Less than: &lt; , greater than: &gt; ampersand: &amp; </message>
EOF
)
new "xml encode <>&"
expecteof $PROG 0 "$XML" "^$XML$"

XML=$(cat <<EOF
<message>To allow attribute values to contain both single and double quotes, the apostrophe or single-quote character ' may be represented as &apos;  and the double-quote character as &quot; </message>
EOF
)
new "xml optional encode single and double quote"
expecteof $PROG 0 "$XML" "^<message>To allow attribute values to contain both single and double quotes, the apostrophe or single-quote character ' may be represented as ' and the double-quote character as \"</message>$"

rm -rf $dir

