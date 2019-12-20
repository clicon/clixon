#!/usr/bin/env bash
# XPATH tests

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

: ${clixon_util_xpath:=clixon_util_xpath}

# XML file (alt provide it in stdin after xpath)
xml=$dir/xml.xml
xml2=$dir/xml2.xml
xml3=$dir/xml3.xml
ydir=$dir/yang

if [ ! -d $ydir ]; then
    mkdir $ydir
fi

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

new "xpath /"
echo "$clixon_util_xpath -f $xml -p /"
expecteof "$clixon_util_xpath -f $xml -p /" 0 "" "^nodeset:0:<aaa><bbb x=\"hello\"><ccc>42</ccc></bbb><bbb x=\"bye\"><ccc>99</ccc></bbb><ddd><ccc>22</ccc></ddd></aaa>$"

new "xpath /aaa"
expecteof "$clixon_util_xpath -f $xml -p /aaa" 0 "" "^nodeset:0:<aaa><bbb x=\"hello\"><ccc>42</ccc></bbb><bbb x=\"bye\"><ccc>99</ccc></bbb><ddd><ccc>22</ccc></ddd></aaa>$"

new "xpath /bbb"
expecteof "$clixon_util_xpath -f $xml -p /bbb" 0 "" "^nodeset:$"

new "xpath /aaa/bbb"
expecteof "$clixon_util_xpath -f $xml -p /aaa/bbb" 0 "" "^0:<bbb x=\"hello\"><ccc>42</ccc></bbb>
1:<bbb x=\"bye\"><ccc>99</ccc></bbb>$"

new "xpath //bbb"
expecteof "$clixon_util_xpath -f $xml -p //bbb" 0 "" "0:<bbb x=\"hello\"><ccc>42</ccc></bbb>
1:<bbb x=\"bye\"><ccc>99</ccc></bbb>"

new "xpath //b?b"
#expecteof "$clixon_util_xpath -f $xml" 0 "//b?b" ""

new "xpath //b*"
#expecteof "$clixon_util_xpath -f $xml" 0 "//b*" ""

new "xpath //b*/ccc"
#expecteof "$clixon_util_xpath -f $xml" 0 "//b*/ccc" ""

new "xpath //bbb[0]"
expecteof "$clixon_util_xpath -f $xml -p //bbb[0]" 0 "" "^nodeset:0:<bbb x=\"hello\"><ccc>42</ccc></bbb>$"

new "xpath //bbb[ccc=99]"
expecteof "$clixon_util_xpath -f $xml -p //bbb[ccc=99]" 0 "" "^nodeset:0:<bbb x=\"bye\"><ccc>99</ccc></bbb>$"

new "xpath ../connection-type = 'responder-only'"
expecteof "$clixon_util_xpath -f $xml2 -p ../connection-type='responder-only' -i /aaa/bbb/here" 0 "" "^bool:true$"

new "xpath ../connection-type = 'no-responder'"
expecteof "$clixon_util_xpath -f $xml2 -p ../connection-type='no-responder' -i /aaa/bbb/here" 0 "" "^bool:false$"

new "xpath . <= 0.75 * ../max-rtr-adv-interval"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb/here" 0 ". <= 0.75 * ../max-rtr-adv-interval" "^bool:true$"

new "xpath . > 0.75 * ../max-rtr-adv-interval"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb/here" 0 ". > 0.75 * ../max-rtr-adv-interval" "^bool:false$"

new "xpath . <= ../valid-lifetime"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb/here" 0 ". <= ../valid-lifetime" "^bool:true$"

new "xpath ../../rt:address-family = 'v6ur:ipv6-unicast'"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb/here" 0 "../../rt:address-family = 'v6ur:ipv6-unicast'" "^bool:true$"

new "xpath ../../../rt:address-family = 'v6ur:ipv6-unicast'"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb/here2/here" 0 "../../../rt:address-family = 'v6ur:ipv6-unicast'" "^bool:true$"

new "xpath /if:interfaces/if:interface[if:name=current()/rt:name]/ip:ipv6/ip:enabled='true'"
expecteof "$clixon_util_xpath -f $xml2" 0 "/if:interfaces/if:interface[if:name=current()/rt:name]/ip:ipv6/ip:enabled='true'" "^bool:true$"

new "xpath rt:address-family='v6ur:ipv6-unicast'"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa" 0 "rt:address-family='v6ur:ipv6-unicast'" "^bool:true$"

new "xpath ../type='rt:static'"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb/here" 0 "../type='rt:static'" "^bool:true$"

new "xpath rib-name != ../../name"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "rib-name != ../name" "^bool:true$"

new "xpath routing/ribs/rib[name=current()/rib-name]/address-family=../../address-family"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "routing/ribs/rib[name=current()/rib-name]/address-family=../../address-family" "^bool:true$"

new "xpath ifType = \"ethernet\" or ifMTU = 1500"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" or ifMTU = 1500" "^bool:true$"

new "xpath ifType != \"ethernet\" or ifMTU = 1500"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" or ifMTU = 1500" "^bool:true$"

new "xpath ifType = \"ethernet\" or ifMTU = 1400"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" or ifMTU = 1400" "^bool:true$"

new "xpath ifType != \"ethernet\" or ifMTU = 1400"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" or ifMTU = 1400" "^bool:false$"

new "xpath ifType = \"ethernet\" and ifMTU = 1500"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" and ifMTU = 1500" "^bool:true$"

new "xpath ifType != \"ethernet\" and ifMTU = 1500"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" and ifMTU = 1500" "^bool:false$"

new "xpath ifType = \"ethernet\" and ifMTU = 1400"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" and ifMTU = 1400" "^bool:false$"

new "xpath ifType != \"ethernet\" and ifMTU = 1400"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" and ifMTU = 1400" "^bool:false$"

new "xpath ifType != \"atm\" or (ifMTU <= 17966 and ifMTU >= 64)"
expecteof "$clixon_util_xpath -f $xml2 -i /aaa/bbb" 0 "ifType != \"atm\" or (ifMTU <= 17966 and ifMTU >= 64)" "^bool:true$"

new "xpath .[name='bar']"
expecteof "$clixon_util_xpath -f $xml2 -p .[name='bar'] -i /aaa/bbb/routing/ribs/rib" 0 "" "^nodeset:0:<rib><name>bar</name><address-family>myfamily</address-family></rib>$"

new "xpath /aaa/bbb/namespace (namespace is xpath axisname)"
echo "$clixon_util_xpath -f $xml2 -p /aaa/bbb/namespace"
expecteof "$clixon_util_xpath -f $xml2 -p /aaa/bbb/namespace" 0 "" "^nodeset:0:<namespace>urn:example:foo</namespace>$"

# See https://github.com/clicon/clixon/issues/54
# But it is not only axis names. There are also, for example, nodetype like this example:
#new "xpath /aaa/bbb/comment (comment is xpath nodetype)"
#expecteof "$clixon_util_xpath -f $xml2 -p /aaa/bbb/comment" 0 "" "^kalle$"

new "Multiple entries"
new "xpath bbb[ccc='foo']"
expecteof "$clixon_util_xpath -f $xml3 -p bbb[ccc='foo']" 0 "" "^nodeset:0:<bbb x=\"hello\"><ccc>foo</ccc><ccc>42</ccc><ccc>bar</ccc></bbb>1:<bbb x=\"bye\"><ccc>99</ccc><ccc>foo</ccc></bbb>$"

new "xpath bbb[ccc='42']"
expecteof "$clixon_util_xpath -f $xml3 -p bbb[ccc='42']" 0 "" "^nodeset:0:<bbb x=\"hello\"><ccc>foo</ccc><ccc>42</ccc><ccc>bar</ccc></bbb>$"

new "xpath bbb[ccc=99] (number w/o quotes)"
expecteof "$clixon_util_xpath -f $xml3 -p bbb[ccc=99]" 0 "" "^nodeset:0:<bbb x=\"bye\"><ccc>99</ccc><ccc>foo</ccc></bbb>$"

new "xpath bbb[ccc='bar']"
expecteof "$clixon_util_xpath -f $xml3 -p bbb[ccc='bar']" 0 "" "^nodeset:0:<bbb x=\"hello\"><ccc>foo</ccc><ccc>42</ccc><ccc>bar</ccc></bbb>$"

new "xpath bbb[ccc='fie']"
expecteof "$clixon_util_xpath -f $xml3 -p bbb[ccc='fie']" 0 "" "^nodeset:$"

# Just syntax - no semantic meaning
new "xpath derived-from-or-self"
expecteof "$clixon_util_xpath -f $xml3 -p 'derived-from-or-self(../../change-operation,modify)'" 0 "" "derived-from-or-self"

rm -rf $dir
