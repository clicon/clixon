#!/usr/bin/env bash
# Test: XML parser tests and JSON translation
#  @see https://www.w3.org/TR/2008/REC-xml-20081126
#       https://www.w3.org/TR/2009/REC-xml-names-20091208
# Note CDATA to JSON: in earlier versions, CDATA was stripped when converting to JSON
# but this has been changed so that the CDATA is a part of the payload, eg shows up also in
# JSON strings

# Magic line must be first in script (see README.md)

s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xml:="clixon_util_xml"}
: ${clixon_util_json:="clixon_util_json"}

new "xml parse"
expecteof "$clixon_util_xml -o" 0 "<a><b/></a>" "^<a><b/></a>$"

# Note dont know what b is.
new "xml parse to json"
expecteof "$clixon_util_xml -oj" 0 "<a><b/></a>" '{"a":{"b":{}}}'

new "xml parse strange names"
expecteof "$clixon_util_xml -o" 0 "<_-><b0.><c-.-._/></b0.></_->" "<_-><b0.><c-.-._/></b0.></_->"

new "xml parse name errors"
expecteof "$clixon_util_xml -o" 255 "<-a/>" ""

new "xml parse name errors"
expecteof "$clixon_util_xml -o" 255 "<9/>" ""

new "xml parse name errors"
expecteof "$clixon_util_xml -o" 255 "<a%/>" ""

LF='
'
new "xml parse content with CR LF -> LF, CR->LF (see https://www.w3.org/TR/REC-xml/#sec-line-ends)"
ret=$(echo "<x>ab${LF}c${LF}d</x>" | $clixon_util_xml -o)
if [ "$ret" != "<x>a${LF}b${LF}c${LF}d</x>" ]; then
     err '<x>a$LFb$LFc</x>' "$ret"
fi

new "xml simple CDATA"
expecteofx "$clixon_util_xml -o" 0 '<a><![CDATA[a text]]></a>' '<a><![CDATA[a text]]></a>'

new "xml CDATA right square bracket: ]"
expecteofx "$clixon_util_xml -o" 0 "<a><![CDATA[]]]></a>" "<a><![CDATA[]]]></a>"

new "xml simple CDATA to json"
expecteofx "$clixon_util_xml -o -j" 0 '<a><![CDATA[a text]]></a>' '{"a":"<![CDATA[a text]]>"}'
# Example partly from https://www.w3resource.com/xml/attribute.php
# XML complex CDATA (with comments for debug):;
DUMMY=$(cat <<EOF
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
# without comments
XML=$(cat <<EOF
<a><description>An example of escaped CENDs</description>
<sometext><![CDATA[ They're saying "x < y" & that "z > y" so I guess that means that z > x ]]></sometext>
<data><![CDATA[This text contains a CEND ]]]]><![CDATA[>]]></data>
<alternative><![CDATA[This text contains a CEND ]]]><![CDATA[]>]]></alternative>
</a>
EOF
   )
XML=$(cat <<'EOF'
<a><description>An example of escaped CENDs</description><sometext><![CDATA[ They're saying "x < y" & that "z > y" so I guess that means that z > x ]]></sometext><data><![CDATA[This text contains a CEND ]]]]><![CDATA[>]]></data><alternative><![CDATA[This text contains a CEND ]]]><![CDATA[]>]]></alternative></a>
EOF
)

new "complex CDATA xml to xml"
expecteof "$clixon_util_xml -o" 0 "$XML" "^$XML
$"

JSON=$(cat <<EOF
{"a":{"description":"An example of escaped CENDs","sometext":"<![CDATA[ They're saying \"x < y\" & that \"z > y\" so I guess that means that z > x ]]>","data":"<![CDATA[This text contains a CEND ]]]]><![CDATA[>]]>","alternative":"<![CDATA[This text contains a CEND ]]]><![CDATA[]>]]>"}}
EOF
)       
new "complex CDATA xml to json"
expecteofx "$clixon_util_xml -oj" 0 "$XML" "$JSON"

# reverse
new "complex CDATA json to json"
expecteofx "$clixon_util_json -j" 0 "$JSON" "$JSON"

# reverse
new "complex CDATA json to xml"
expecteofx "$clixon_util_json" 0 "$JSON" "$XML"

XML=$(cat <<EOF
<message>Less than: &lt; , greater than: &gt; ampersand: &amp; </message>
EOF
)
new "xml encode <>&"
expecteof "$clixon_util_xml -o" 0 "$XML" "$XML"

new "xml encode <>& to json"
expecteof "$clixon_util_xml -oj" 0 "$XML" '{"message":"Less than: < , greater than: > ampersand: & "}'

XML=$(cat <<EOF
<message>single-quote character ' represented as &apos; and double-quote character as &quot;</message>
EOF
)
new "xml single and double quote"
expecteof "$clixon_util_xml -o" 0 "$XML" "<message>single-quote character ' represented as ' and double-quote character as \"</message>"

JSON=$(cat <<EOF
{"message":"single-quote character ' represented as ' and double-quote character as \""}
EOF
)
new "xml single and double quotes to json"
expecteofx "$clixon_util_xml -oj" 0 "$XML" "$JSON"

new "xml backspace"
expecteofx "$clixon_util_xml -o" 0 "<a>a\b</a>" "<a>a\b</a>"

new "xml backspace to json"
expecteofx "$clixon_util_xml -oj" 0 "<a>a\b</a>" '{"a":"a\\b"}'

new "Double quotes for attributes"
expecteof "$clixon_util_xml -o" 0 '<x a="t"/>' '<x a="t"/>'

new "Single quotes for attributes (returns double quotes but at least parses right)"
expecteof "$clixon_util_xml -o" 0 "<x a='t'/>" '<x a="t"/>'

new "Mixed quotes"
expecteof "$clixon_util_xml -o" 0 "<x a='t' b=\"q\"/>" '<x a="t" b="q"/>'

new "XMLdecl version"
expecteof "$clixon_util_xml -o" 0 '<?xml version="1.0"?><a/>' '<a/>'

new "XMLdecl version, single quotes"
expecteof "$clixon_util_xml -o" 0 "<?xml version='1.0'?><a/>" '<a/>'

new "XMLdecl version no element"
expecteof "$clixon_util_xml -o" 255 '<?xml version="1.0"?>' '' 2> /dev/null

new "XMLdecl no version"
expecteof "$clixon_util_xml -o" 255 '<?xml ?><a/>' '' 2> /dev/null

new "XMLdecl misspelled version"
expecteof "$clixon_util_xml -ol o" 255 '<?xml verion="1.0"?><a/>' '' 2> /dev/null

new "XMLdecl version + encoding"
expecteof "$clixon_util_xml -o" 0 '<?xml version="1.0" encoding="UTF-8"?><a/>' '<a/>'

# XML processors SHOULD match character encoding names in a case-insensitive way 
new "XMLdecl encoding case-insensitive"
expecteof "$clixon_util_xml -o" 0 '<?xml version="1.0" encoding="utf-8"?><a/>' '<a/>'

new "XMLdecl version + wrong encoding"
expecteof "$clixon_util_xml -o" 255 '<?xml version="1.0" encoding="UTF-16"?><a/>' '' 2> /dev/null

new "XMLdecl version + misspelled encoding"
expecteof "$clixon_util_xml -ol o" 255 '<?xml version="1.0" encding="UTF-16"?><a/>' 'syntax error: at or before: e' 2> /dev/null

new "XMLdecl version + standalone"
expecteof "$clixon_util_xml -o" 0 '<?xml version="1.0" standalone="yes"?><a/>' '<a/>'

new "PI - Processing instruction empty"
expecteof "$clixon_util_xml -o" 0 '<?foo ?><a/>' '<a/>'

new "PI some content"
expecteof "$clixon_util_xml -o" 0 '<?foo something else ?><a/>' '<a/>'

new "prolog element misc*"
expecteof "$clixon_util_xml -o" 0 '<?foo something ?><a/><?bar more stuff ?><!-- a comment-->' '<a/>'
					
# We allow it as an internal necessity for parsing of xml fragments
#new "double element error"
#expecteof "$clixon_util_xml" 255 '<a/><b/>' ''

new "namespace: DefaultAttName"
expecteof "$clixon_util_xml -o" 0 '<x xmlns="n1">hello</x>' '<x xmlns="n1">hello</x>'

new "namespace: PrefixedAttName"
expecteof "$clixon_util_xml -o" 0 '<x xmlns:n2="urn:example:des"><n2:y>hello</n2:y></x>' '^<x xmlns:n2="urn:example:des"><n2:y>hello</n2:y></x>$'

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
expecteof "$clixon_util_xml -o" 0 "$XML" '^<html:html xmlns:html="http://www.w3.org/1999/xhtml"><html:head><html:title>Frobnostication</html:title></html:head><html:body><html:p><html:a href="http://frob.example.com">here.</html:a></html:p></html:body></html:html>$'

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
expecteof "$clixon_util_xml -o" 0 "$XML" '^<bk:book xmlns:bk="urn:loc.gov:books" xmlns:isbn="urn:ISBN:0-395-36341-6"><bk:title>Cheaper by the Dozen</bk:title><isbn:number>1568491379</isbn:number></bk:book>$'

rm -rf $dir

# unset conditional parameters 
unset clixon_util_xml

new "endtest"
endtest
