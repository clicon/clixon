#!/bin/bash
# Test: XML parser tests and JSON translation
#  @see https://www.w3.org/TR/2008/REC-xml-20081126
#       https://www.w3.org/TR/2009/REC-xml-names-20091208
#PROG="valgrind --leak-check=full --show-leak-kinds=all ../util/clixon_util_xml"
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xml:=clixon_util_xml -o} # -o is output

new "xml parse"
expecteof "$clixon_util_xml" 0 "<a><b/></a>" "^<a><b/></a>$"

new "xml parse to json"
expecteof "$clixon_util_xml -j" 0 "<a><b/></a>" '{"a":{"b":null}}'

new "xml parse strange names"
expecteof "$clixon_util_xml" 0 "<_-><b0.><c-.-._/></b0.></_->" "<_-><b0.><c-.-._/></b0.></_->"

new "xml parse name errors"
expecteof "$clixon_util_xml" 255 "<-a/>" ""

new "xml parse name errors"
expecteof "$clixon_util_xml" 255 "<9/>" ""

new "xml parse name errors"
expecteof "$clixon_util_xml" 255 "<a%/>" ""

LF='
'
new "xml parse content with CR LF -> LF, CR->LF (see https://www.w3.org/TR/REC-xml/#sec-line-ends)"
ret=$(echo "<x>ab${LF}c${LF}d</x>" | $clixon_util_xml)
if [ "$ret" != "<x>a${LF}b${LF}c${LF}d</x>" ]; then
     err '<x>a$LFb$LFc</x>' "$ret"
fi

new "xml simple CDATA"
expecteofx "$clixon_util_xml" 0 '<a><![CDATA[a text]]></a>' '<a><![CDATA[a text]]></a>'

new "xml simple CDATA to json"
expecteofx "$clixon_util_xml -j" 0 '<a><![CDATA[a text]]></a>' '{"a":"a text"}' 

new "xml complex CDATA"
XML=$(cat <<EOF
<a><description>An example of escaped CENDs</description>
<sometext><![CDATA[ They're saying "x < y" & that "z > y" so I guess that means that z > x ]]></sometext>
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

expecteof "$clixon_util_xml" 0 "$XML" "^<a><description>An example of escaped CENDs</description><sometext>
<![CDATA[ They're saying \"x < y\" & that \"z > y\" so I guess that means that z > x ]]>
</sometext><data><![CDATA[This text contains a CEND ]]]]><![CDATA[>]]></data><alternative><![CDATA[This text contains a CEND ]]]><![CDATA[]>]]></alternative></a>$"

JSON=$(cat <<EOF
{"a":{"description":"An example of escaped CENDs","sometext":" They're saying \"x < y\" & that \"z > y\" so I guess that means that z > x ","data":"This text contains a CEND ]]>","alternative":"This text contains a CEND ]]>"}}
EOF
)       
new "xml complex CDATA to json"
expecteofx "$clixon_util_xml -j" 0 "$XML" "$JSON"

XML=$(cat <<EOF
<message>Less than: &lt; , greater than: &gt; ampersand: &amp; </message>
EOF
)
new "xml encode <>&"
expecteof "$clixon_util_xml" 0 "$XML" "$XML"

new "xml encode <>& to json"
expecteof "$clixon_util_xml -j" 0 "$XML" '{"message":"Less than: < , greater than: > ampersand: & "}'

XML=$(cat <<EOF
<message>single-quote character ' represented as &apos; and double-quote character as &quot;</message>
EOF
)
new "xml single and double quote"
expecteof "$clixon_util_xml" 0 "$XML" "<message>single-quote character ' represented as ' and double-quote character as \"</message>"

JSON=$(cat <<EOF
{"message":"single-quote character ' represented as ' and double-quote character as \""}
EOF
)
new "xml single and double quotes to json"
expecteofx "$clixon_util_xml -j" 0 "$XML" "$JSON"

new "xml backspace"
expecteofx "$clixon_util_xml" 0 "<a>a\b</a>" "<a>a\b</a>"

new "xml backspace to json"
expecteofx "$clixon_util_xml -j" 0 "<a>a\b</a>" '{"a":"a\\b"}'

new "Double quotes for attributes"
expecteof "$clixon_util_xml" 0 '<x a="t"/>' '<x a="t"/>'

new "Single quotes for attributes (returns double quotes but at least parses right)"
expecteof "$clixon_util_xml" 0 "<x a='t'/>" '<x a="t"/>'

new "Mixed quotes"
expecteof "$clixon_util_xml" 0 "<x a='t' b=\"q\"/>" '<x a="t" b="q"/>'

new "XMLdecl version"
expecteof "$clixon_util_xml" 0 '<?xml version="1.0"?><a/>' '<a/>'

new "XMLdecl version, single quotes"
expecteof "$clixon_util_xml" 0 "<?xml version='1.0'?><a/>" '<a/>'

new "XMLdecl version no element"
expecteof "$clixon_util_xml" 255 '<?xml version="1.0"?>' ''

new "XMLdecl no version"
expecteof "$clixon_util_xml" 255 '<?xml ?><a/>' ''

new "XMLdecl misspelled version"
expecteof "$clixon_util_xml -l o" 255 '<?xml verion="1.0"?><a/>' ''

new "XMLdecl version + encoding"
expecteof "$clixon_util_xml" 0 '<?xml version="1.0" encoding="UTF-16"?><a/>' '<a/>'

new "XMLdecl version + misspelled encoding"
expecteof "$clixon_util_xml -l o" 255 '<?xml version="1.0" encding="UTF-16"?><a/>' 'syntax error: at or before: e'

new "XMLdecl version + standalone"
expecteof "$clixon_util_xml" 0 '<?xml version="1.0" standalone="yes"?><a/>' '<a/>'

new "PI - Processing instruction empty"
expecteof "$clixon_util_xml" 0 '<?foo ?><a/>' '<a/>'

new "PI some content"
expecteof "$clixon_util_xml" 0 '<?foo something else ?><a/>' '<a/>'

new "prolog element misc*"
expecteof "$clixon_util_xml" 0 '<?foo something ?><a/><?bar more stuff ?><!-- a comment-->' '<a/>'

# We allow it as an internal necessity for parsing of xml fragments
#new "double element error"
#expecteof "$clixon_util_xml" 255 '<a/><b/>' ''

new "namespace: DefaultAttName"
expecteof "$clixon_util_xml" 0 '<x xmlns="n1">hello</x>' '<x xmlns="n1">hello</x>'

new "namespace: PrefixedAttName"
expecteof "$clixon_util_xml" 0 '<x xmlns:n2="urn:example:des"><n2:y>hello</n2:y></x>' '^<x xmlns:n2="urn:example:des"><n2:y>hello</n2:y></x>$'

new "First example 6.1 from https://www.w3.org/TR/2009/REC-xml-names-20091208"
XML=$(cat <<EOF
<?xml version="1.0"?>

<html:html xmlns:html='http://www.w3.org/1999/xhtml'>

  <html:head><html:title>Frobnostication</html:title></html:head>
  <html:body><html:p>Moved to 
    <html:a href='http://frob.example.com'>here.</html:a></html:p></html:body>
</html:html>
EOF
)
expecteof "$clixon_util_xml" 0 "$XML" "$XML"

new "Second example 6.1 from https://www.w3.org/TR/2009/REC-xml-names-20091208"
XML=$(cat <<EOF
<?xml version="1.0"?>
<!-- both namespace prefixes are available throughout -->
<bk:book xmlns:bk='urn:loc.gov:books'
         xmlns:isbn='urn:ISBN:0-395-36341-6'>
    <bk:title>Cheaper by the Dozen</bk:title>
    <isbn:number>1568491379</isbn:number>
</bk:book>
EOF
)
expecteof "$clixon_util_xml" 0 "$XML" "$XML"
      
rm -rf $dir

