#!/usr/bin/env bash
# Basic XPATH tests
# See also test_xpath_functions.sh for XPaths with YANG conditionals
# Some XPATH cases clixon cannot handle
# - /aaa/bbb/comment, where "comment" is nodetype
# - //b*, combinations of // and "*"
# Test has three parts:
# - Only XML no YANG
# - negative tests with YANG
# - simple key/value test with YANG

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xpath:=clixon_util_xpath}

# XML file (alt provide it in stdin after xpath)
xml=$dir/xml.xml
xml2=$dir/xml2.xml
xml3=$dir/xml3.xml
xml4=$dir/xml4.xml
xmlfn=$dir/xmlfn.xml

fyang=$dir/clixon-example.yang

cat <<EOF > $xml
<aaa>
  <bbb x="hello">
      <ccc>42</ccc>
  </bbb>
  <bbb x="bye">
      <ccc>99</ccc>
  </bbb>
  <ddd>
      <ccc>22</ccc>
  </ddd>
</aaa>
EOF

cat <<EOF > $xml2
<if:interfaces xmlns:if="urn:example:if" xmlns:ip="urn:example:ip">
  <if:interface>
    <if:name>e0</if:name>
    <ip:ipv6>
      <ip:enabled>true</ip:enabled>
    </ip:ipv6>
  </if:interface>
</if:interfaces>
<rt:name xmlns:rt="urn:example:rt">e0</rt:name>
<address-family>myfamily</address-family>
<aaa xmlns:rt="urn:example:rt">
  <rt:address-family>v6ur:ipv6-unicast</rt:address-family>
  <name>foo</name>
  <bbb>
    <routing>
      <ribs>
        <rib>
          <name>bar</name>
          <address-family>myfamily</address-family>
        </rib>
      </ribs>
    </routing>
    <max-rtr-adv-interval>22</max-rtr-adv-interval>
    <valid-lifetime>99</valid-lifetime>
    <connection-type>responder-only</connection-type>
    <type>rt:static</type>
    <rib-name>bar</rib-name>
    <here>0</here>
    <here2><here/></here2>
    <ifType>ethernet</ifType>
    <ifMTU>1500</ifMTU>
    <namespace>urn:example:foo</namespace>
    <mylength>7</mylength>
    <myaddr>10.22.33.44</myaddr>
  </bbb>
</aaa>
EOF

# Multiple leaf-list
cat <<EOF > $xml3
<bbb x="hello">
      <ccc>foo</ccc>
      <ccc>42</ccc>
      <ccc>bar</ccc>
</bbb>
<bbb x="bye">
      <ccc>99</ccc>
      <ccc>foo</ccc>
</bbb>
EOF

# Asterisk
cat <<EOF > $xml4
<root>
  <x>
    <a>111</a>
  </x>
  <y>
    <a>222</a>
  </y>
  <z>
    <b>111</b>
  </z>
  <w>
    <a>111</a>
  </w>
</root>
EOF

# XPath functions
cat <<EOF > $xmlfn
<root>
  <ancestor>
    <count>
      <node>42</node>
    </count>
  </ancestor>
  <count>
    <node>
      <ancestor>99</ancestor>
    </node>
  </count>
  <node>
    <ancestor>
      <count>73</count>
    </ancestor>
  </node>
</root>
EOF

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    container table{
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
        }
        container options {
           leaf max-number {
               type uint32;
               default 50000;
            }
        }
    }
}
EOF

new "xpath not(aaa)"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p "not(aaa)")" 0 "bool:false"

new "xpath not (aaa)  - delimiter"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p "not(aaa)")" 0 "bool:false"

new "xpath not(xyz)"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p "not(xyz)")" 0 "bool:true"

new "xpath /"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p /)" 0 "^nodeset:0:<aaa><bbb x=\"hello\"><ccc>42</ccc></bbb><bbb x=\"bye\"><ccc>99</ccc></bbb><ddd><ccc>22</ccc></ddd></aaa>$"

new "xpath /aaa"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p /aaa)" 0 "^nodeset:0:<aaa><bbb x=\"hello\"><ccc>42</ccc></bbb><bbb x=\"bye\"><ccc>99</ccc></bbb><ddd><ccc>22</ccc></ddd></aaa>$"

new "xpath aaa"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p aaa)" 0 "^nodeset:0:<aaa><bbb x=\"hello\"><ccc>42</ccc></bbb><bbb x=\"bye\"><ccc>99</ccc></bbb><ddd><ccc>22</ccc></ddd></aaa>$"

new "xpath /bbb"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p /bbb)" 0 "^nodeset:$" 

new "xpath /aaa/bbb"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p /aaa/bbb)" 0  "^0:<bbb x=\"hello\"><ccc>42</ccc></bbb>
1:<bbb x=\"bye\"><ccc>99</ccc></bbb>$"

new "xpath /aaa/bbb union "
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p "aaa/bbb[ccc=42]|aaa/ddd[ccc=22]")" 0 '^nodeset:0:<bbb x="hello"><ccc>42</ccc></bbb>1:<ddd><ccc>22</ccc></ddd>$'

new "xpath //bbb"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p //bbb)" 0 "0:<bbb x=\"hello\"><ccc>42</ccc></bbb>" "1:<bbb x=\"bye\"><ccc>99</ccc></bbb>"

new "xpath //ccc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p //ccc)" 0 "0:<ccc>42</ccc>" "1:<ccc>99</ccc>" "2:<ccc>22</ccc>"

new "xpath /descendant-or-self::node()/ccc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p /descendant-or-self::node\(\)/ccc)" 0 "0:<ccc>42</ccc>" "1:<ccc>99</ccc>" "2:<ccc>22</ccc>"

new "xpath /aaa//ccc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p /aaa//ccc)" 0 "0:<ccc>42</ccc>" "1:<ccc>99</ccc>" "2:<ccc>22</ccc>"

new "xpath /aaa/descendant-or-self::node()/ccc"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p /aaa/descendant-or-self::node\(\)/ccc)" 0 "0:<ccc>42</ccc>" "1:<ccc>99</ccc>" "2:<ccc>22</ccc>"

new "xpath //b?b"
#expecteof "$clixon_util_xpath -D $DBG -f $xml" 0 "//b?b" ""

# Clixon cant do //* things
new "xpath //b*"
#expecteof "$clixon_util_xpath -D $DBG -f $xml" 0 "//b*" ""

new "xpath //b*/ccc"
#expecteof "$clixon_util_xpath -D $DBG -f $xml" 0 "//b*/ccc" ""

new "xpath //bbb[0]"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p //bbb[0])" 0 "^nodeset:0:<bbb x=\"hello\"><ccc>42</ccc></bbb>$"

new "xpath //bbb[ccc=99]"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p //bbb[ccc=99])" 0 "^nodeset:0:<bbb x=\"bye\"><ccc>99</ccc></bbb>$"

new "Negative: xpath [x=] on a variable that has no body"
expectpart "$($clixon_util_xpath -D $DBG -f $xml -p "/aaa[bbb='a']")" 0 "nodeset:"

new "xpath ../connection-type = 'responder-only'"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "../connection-type='responder-only'" -i /aaa/bbb/here)" 0 "^bool:true$"

new "xpath ../connection-type = 'no-responder'"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "../connection-type='no-responder'" -i /aaa/bbb/here)" 0 "^bool:false$"

new "xpath . <= 0.75 * ../max-rtr-adv-interval"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb/here" 0 ". <= 0.75 * ../max-rtr-adv-interval" "^bool:true$"

new "xpath . > 0.75 * ../max-rtr-adv-interval"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb/here" 0 ". > 0.75 * ../max-rtr-adv-interval" "^bool:false$"

new "xpath . <= ../valid-lifetime"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb/here" 0 ". <= ../valid-lifetime" "^bool:true$"

new "xpath ../../rt:address-family = 'v6ur:ipv6-unicast'"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb/here" 0 "../../rt:address-family = 'v6ur:ipv6-unicast'" "^bool:true$"

new "xpath ../../../rt:address-family = 'v6ur:ipv6-unicast'"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb/here2/here" 0 "../../../rt:address-family = 'v6ur:ipv6-unicast'" "^bool:true$"

new "xpath /if:interfaces/if:interface[if:name=current()/rt:name]/ip:ipv6/ip:enabled='true'"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "/if:interfaces/if:interface[if:name=current()/rt:name]/ip:ipv6/ip:enabled='true'")" 0 "^bool:true$"

new "xpath rt:address-family='v6ur:ipv6-unicast'"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa" 0 "rt:address-family='v6ur:ipv6-unicast'" "^bool:true$"

new "xpath ../type='rt:static'"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb/here" 0 "../type='rt:static'" "^bool:true$"

new "xpath rib-name != ../../name"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "rib-name != ../name" "^bool:true$"

new "xpath routing/ribs/rib[name=current()/rib-name]/address-family=../../address-family"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "routing/ribs/rib[name=current()/rib-name]/address-family=../../address-family" "^bool:true$"

new "xpath ifType = \"ethernet\" or ifMTU = 1500"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" or ifMTU = 1500" "^bool:true$"

new "xpath ifType != \"ethernet\" or ifMTU = 1500"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" or ifMTU = 1500" "^bool:true$"

new "xpath ifType = \"ethernet\" or ifMTU = 1400"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" or ifMTU = 1400" "^bool:true$"

new "xpath ifType != \"ethernet\" or ifMTU = 1400"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" or ifMTU = 1400" "^bool:false$"

new "xpath ifType = \"ethernet\" and ifMTU = 1500"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" and ifMTU = 1500" "^bool:true$"

new "xpath ifType != \"ethernet\" and ifMTU = 1500"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" and ifMTU = 1500" "^bool:false$"

new "xpath ifType = \"ethernet\" and ifMTU = 1400"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" and ifMTU = 1400" "^bool:false$"

new "xpath ifType != \"ethernet\" and ifMTU = 1400"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" and ifMTU = 1400" "^bool:false$"

new "xpath ifType != \"atm\" or (ifMTU <= 17966 and ifMTU >= 64)"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -i /aaa/bbb" 0 "ifType != \"atm\" or (ifMTU <= 17966 and ifMTU >= 64)" "^bool:true$"

new "xpath .[name='bar']"
expecteof "$clixon_util_xpath -D $DBG -f $xml2 -p .[name='bar'] -i /aaa/bbb/routing/ribs/rib" 0 "^nodeset:0:<rib><name>bar</name><address-family>myfamily</address-family></rib>$"

new "xpath /aaa/bbb/namespace (namespace is xpath axisname)"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p /aaa/bbb/namespace)" 0 "^nodeset:0:<namespace>urn:example:foo</namespace>$"

# See https://github.com/clicon/clixon/issues/54
# But it is not only axis names. There are also, for example, nodetype like this example:
new "xpath /aaa/bbb/comment (comment is xpath nodetype)"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p /aaa/bbb/comment)" 0 "^nodeset:$"

new "Multiple entries"
new "xpath bbb[ccc='foo']"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "bbb[ccc='foo']")" 0 "^nodeset:0:<bbb x=\"hello\"><ccc>foo</ccc><ccc>42</ccc><ccc>bar</ccc></bbb>1:<bbb x=\"bye\"><ccc>99</ccc><ccc>foo</ccc></bbb>$"

new "xpath bbb[ccc=\"foo\"]"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "bbb[ccc=\"foo\"]")" 0 "^nodeset:0:<bbb x=\"hello\"><ccc>foo</ccc><ccc>42</ccc><ccc>bar</ccc></bbb>1:<bbb x=\"bye\"><ccc>99</ccc><ccc>foo</ccc></bbb>$"

new "xpath bbb[ccc='42']"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p bbb[ccc='42'])" 0 "^nodeset:0:<bbb x=\"hello\"><ccc>foo</ccc><ccc>42</ccc><ccc>bar</ccc></bbb>$"

new "xpath bbb[ccc=99] (number w/o quotes)"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p bbb[ccc=99])" 0 "^nodeset:0:<bbb x=\"bye\"><ccc>99</ccc><ccc>foo</ccc></bbb>$"

new "xpath bbb[ccc='bar']"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "bbb[ccc='bar']")" 0 "^nodeset:0:<bbb x=\"hello\"><ccc>foo</ccc><ccc>42</ccc><ccc>bar</ccc></bbb>$"

new "xpath bbb[ccc='fie']"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "bbb[ccc='fie']")" 0 "^nodeset:$"

# Just syntax - no semantic meaning
new "xpath derived-from 10.4.1"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p 'derived-from(../../change-operation,"modify")')" 0 "bool:false"

new "xpath derived-from-or-self"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p 'derived-from-or-self(../../change-operation,"modify")')" 0 "bool:false"

# re-match
new "xpath re-match match true" # example from rfc 7950
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p 're-match("1.22.333", "\d{1,3}\.\d{1,3}\.\d{1,3}")')" 0 "bool:true"

new "xpath re-match match path"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p 're-match(aaa/bbb/myaddr, "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}")')" 0 "bool:true"

new "xpath re-match match path fail"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p 're-match(aaa/bbb/myaddr, "\d{1,3}\.\d{1,3}\.\d{1,3}")')" 0 "bool:false"

# string
new "xpath string empty"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "string()")" 0 "string:$"

new "xpath string path"
expectpart "$($clixon_util_xpath -D $DBG -f $xml4 -p "string(root/y/a)")" 0 "string:222$"

# starts-with
new "xpath starts-with true"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "starts-with('kalle','kal')")" 0 "bool:true"

new "xpath starts-with false"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "starts-with('kalle','all')")" 0 "bool:false"

new "xpath starts-with empty"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "starts-with('kalle','')")" 0 "bool:true"

new "xpath starts-with too long"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "starts-with('kalle','kalle42')")" 0 "bool:false"

new "xpath contains direct strings true"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "contains('kalle','all')")" 0 "bool:true"

new "xpath contains direct strings false"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "contains('kalle','ball')")" 0 "bool:false"

new "xpath contains path true"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "contains(aaa/bbb/namespace,aaa/name)")" 0 "bool:true"

new "xpath contains path false"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "contains(aaa/bbb/ifMTU,aaa/name)")" 0 "bool:false"

# substring-before / after
new "xpath substring-before 1"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring-before(\"1999/04/01\",\"/\")")" 0 "string:1999" --not-- "1999/"

new "xpath substring-before 2"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring-before(\"1999/04/01\",\"04\")")" 0 "string:1999/" --not-- "04"

new "xpath substring-before 3"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring-before(\"1999/04/01\",\"zzz\")")" 0 "string:" --not-- "string:1"

new "xpath substring-after 1"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring-after(\"1999/04/01\",\"/\")")" 0 "string:04/01"

new "xpath substring-after 2"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring-after(\"1999/04/01\",\"19\")")" 0 "string:99/04/01"

new "xpath substring-after 3"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring-after(\"1999/04/01\",\"z\")")" 0 "string:" --not-- "1999"

# substring, see examples in https://www.w3.org/TR/xpath-10/ Sections 4.2
new "xpath substring 1"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring(\"12345\",2,3)")" 0 "string:234" --not-- "45"

new "xpath substring 2"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring(\"12345\",1.5,2.6)")" 0 "string:234" --not-- "45"

new "xpath substring 3"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring(\"12345\",0,3)")" 0 "string:12" --not-- "123"

new "xpath substring 4"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring(\"12345\",0 div 0,3)")" 0 "string:" --not-- "12"

new "xpath substring 5"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring(\"12345\",1, 0 div 0)")" 0 "string:" --not-- "12"

# XXX cornercase does not work
#new "xpath substring 6"
#expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring(\"12345\",-42, 1 div 0)")" 0 "string:12345"

new "xpath substring 7"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring(\"12345\",-1, 1 div 0)")" 0 "string:" --not-- "string:1"

new "xpath substring paths"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "substring(aaa/bbb/namespace,5,aaa/bbb/mylength)")" 0 "string:example" --not-- "example:"

# string-length
new "xpath string-length empty" # XXX without args not supported
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "string-length()")" 0 "number:0"

new "xpath string-length direct"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "string-length(\"12345\")")" 0 "number:5"

new "xpath string-length path"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "string-length(aaa/name)")" 0 "number:3"

# translate
new "xpath translate" # modified
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "translate(\"bar\", \"abc\",\"DEF\")")" 0 "string:EDr$"

new "xpath translate remove"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "translate(\"--aaa--\", \"abc-\",\"DEF\")")" 0 "string:DDD$"

new "xpath translate none"
expectpart "$($clixon_util_xpath -D $DBG -f $xml2 -p "translate(\"bar\", \"cde-\",\"fgh\")")" 0 "string:bar$"

# Nodetests

new "xpath nodetest: node"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -p "/bbb/ccc/self::node()")" 0 "nodeset:0:<ccc>foo</ccc>"

new "xpath nodetest: comment nyi"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -l o -p "/descendant-or-self::comment()")" 255 "XPATH function \"comment\" is not implemented"

# Count

new "find bbb with 3 ccc children using count"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -l o -p "(/bbb[count(ccc)=3])")" 0 "<bbb x=\"hello\"><ccc>foo</ccc><ccc>42</ccc><ccc>bar</ccc></bbb>"

# Negative

new "xpath dontexist"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -l o -p "dontexist()")" 255 "Unknown xpath function \"dontexist\""

new "xpath enum-value nyi"
expectpart "$($clixon_util_xpath -D $DBG -f $xml3 -l o -p "enum-value()")" 255 "XPATH function \"enum-value\" is not implemented"

new "xpath /root/*/a"
expecteof "$clixon_util_xpath -D $DBG -f $xml4 -p /root/*/a" 0 "" "nodeset:0:<a>111</a>1:<a>222</a>2:<a>111</a>"

new "xpath /root/*/b"
expecteof "$clixon_util_xpath -D $DBG -f $xml4 -p /root/*/b" 0 "" "nodeset:0:<b>111</b>"

new "xpath /root/*/*[.='111']"
expecteof "$clixon_util_xpath -D $DBG -f $xml4 -p /root/*/*[.='111']" 0 "" "nodeset:0:<a>111</a>1:<b>111</b>2:<a>111</a>"

# Try functionnames in place of node nc-names
new "xpath nodetest: node"
expectpart "$($clixon_util_xpath -D $DBG -f $xmlfn -p "count(/root/count)")" 0 "number:1"

new "xpath nodetest: node"
expectpart "$($clixon_util_xpath -D $DBG -f $xmlfn -p "/root/node/self::node()")" 0 "<node><ancestor><count>73</count></ancestor></node>"

new "xpath functions as ncname: nodetype:node"
expectpart "$($clixon_util_xpath -D $DBG -f $xmlfn -p "root/ancestor/count/node")" 0 "<node>42</node>"

new "xpath functions as ncname: nodetype:node"
expectpart "$($clixon_util_xpath -D $DBG -f $xmlfn -p "root/ancestor/count[node=42]")" 0 "<count><node>42</node></count>"

new "xpath functions as ncname: axisname:ancestor"
expectpart "$($clixon_util_xpath -D $DBG -f $xmlfn -p "root/count/node[99=ancestor]")" 0 "<node><ancestor>99</ancestor></node>"

new "xpath functions as ncname: functioname:count"
expectpart "$($clixon_util_xpath -D $DBG -f $xmlfn -p "root/node/ancestor[73=count]")" 0 "<ancestor><count>73</count></ancestor>"

new "xpath functions: number"
expectpart "$($clixon_util_xpath -D $DBG -f $xmlfn -p "root/node/ancestor[73=count]")" 0 "<ancestor><count>73</count></ancestor>"

# PART 2
# Negative tests from fuzz crashes
cat <<EOF > $dir/1.xml
<table xmlns="urn:example:clixon">
   <parameter>
      <name>x</name>
      <value>42</value>
   </parameter>
</table>
EOF

cat <<EOF > $dir/1.xpath
/ex:table=ex*paramet
EOF

new "negative xpath 1"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "bool:false"

cat <<EOF > $dir/1.xpath
ter='x'/ex:table[exmeter='x']
EOF

new "negative xpath 2"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "bool:false"

cat <<EOF > $dir/1.xpath
/ex:table<ex*ptramble
EOF

new "negative xpath 3"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "bool:false"

cat <<EOF > $dir/1.xpath
7/ex:table['x']
EOF

new "negative xpath 4"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "number:7"

cat <<EOF > $dir/1.xpath
/>meter*//ter
EOF

new "negative xpath 5"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "bool:false"

cat <<EOF > $dir/1.xpath
7=/ ter
EOF

new "negative xpath 6"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "bool:false"

cat <<EOF > $dir/1.xpath
/=7 ter
EOF

new "negative xpath 7"
#expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "bool:false"

cat <<EOF > $dir/1.xpath
*<-9****
EOF

new "negative xpath 8"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "bool:false"

# PART 3


cat <<EOF > $dir/1.xpath
/table/parameter[name='x']/name
EOF

new "given key show key"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "<name>x</name>"

cat <<EOF > $dir/1.xpath
/table/parameter[name='x']/value
EOF

new "given key show value"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "<value>42</value>"

cat <<EOF > $dir/1.xpath
/table/parameter[value='42']/name
EOF

new "given value show key"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "<name>x</name>"

# See https://github.com/clicon/clixon/issues/594
cat <<EOF > $dir/1.xpath
/table/parameter[value='42']/value
EOF

new "given value show value"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang < $dir/1.xpath)" 0 "<value>42</value>"

cat <<EOF > $dir/1.xml
<table xmlns="urn:example:clixon">
   <options>
         <max-number>50000</max-number>
   </options>
</table>
EOF

new "xpath issue ok"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang -p "/ex:table/ex:options/*")" 0 "<max-number>50000</max-number>"

new "xpath number"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang -p "number(/ex:table/ex:options/ex:max-number)")" 0 "50000"

new "xpath empty number"
expectpart "$($clixon_util_xpath -D $DBG -i "/table" -f $dir/1.xml -n ex:urn:example:clixon -y $fyang -p "number()")" 0 "0.000"

new "xpath concat"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n ex:urn:example:clixon -y $fyang -p "concat(\"mynumber:\", /ex:table/ex:options/ex:max-number)")" 0 "mynumber:50000"

new "xpath issue fail"
expectpart "$($clixon_util_xpath -D $DBG -f $dir/1.xml -n null:urn:ietf:params:xml:ns:netconf:base:1.0 -n ex:urn:example:clixon -y $fyang -p "/ex:table/ex:options/*")" 0 "<max-number>50000</max-number>"

rm -rf $dir

new "endtest"
endtest
