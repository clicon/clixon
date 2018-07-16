#!/bin/bash
# Test: XPATH tests
PROG=../lib/src/clixon_util_xpath

# include err() and new() functions and creates $dir
. ./lib.sh

# XML file (alt provide it in stdin after xpath)
xml=$dir/xml.xml
xml2=$dir/xml2.xml

cat <<EOF > $xml
<aaa>
  <bbb x="hello"><ccc>42</ccc></bbb>
  <bbb x="bye"><ccc>99</ccc></bbb>
  <ddd><ccc>22</ccc></ddd>
</aaa>
EOF

cat <<EOF > $xml2
<if:interfaces>
  <if:interface>
    <if:name>e0</if:name>
    <ip:ipv6>
      <ip:enabled>true</ip:enabled>
    </ip:ipv6>
  </if:interface>
</if:interfaces>
<rt:name>e0</rt:name>
<address-family>myfamily</address-family>
<aaa>
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
  </bbb>
</aaa>
EOF

new "xpath /"
expecteof "$PROG -f $xml -p /" 0 "" "^nodeset:0:<aaa><bbb x=\"hello\"><ccc>42</ccc></bbb><bbb x=\"bye\"><ccc>99</ccc></bbb><ddd><ccc>22</ccc></ddd></aaa>$"

new "xpath /aaa"
expecteof "$PROG -f $xml -p /aaa" 0 "" "^nodeset:0:<aaa><bbb x=\"hello\"><ccc>42</ccc></bbb><bbb x=\"bye\"><ccc>99</ccc></bbb><ddd><ccc>22</ccc></ddd></aaa>$"

new "xpath /bbb"
expecteof "$PROG -f $xml -p /bbb" 0 "" "^nodeset:$"

new "xpath /aaa/bbb"
expecteof "$PROG -f $xml -p /aaa/bbb" 0 "" "^0:<bbb x=\"hello\"><ccc>42</ccc></bbb>
1:<bbb x=\"bye\"><ccc>99</ccc></bbb>$"

new "xpath //bbb"
expecteof "$PROG -f $xml -p //bbb" 0 "" "0:<bbb x=\"hello\"><ccc>42</ccc></bbb>
1:<bbb x=\"bye\"><ccc>99</ccc></bbb>"

new "xpath //b?b"
#expecteof "$PROG -f $xml" 0 "//b?b" ""

new "xpath //b*"
#expecteof "$PROG -f $xml" 0 "//b*" ""

new "xpath //b*/ccc"
#expecteof "$PROG -f $xml" 0 "//b*/ccc" ""

new "xpath //bbb[0]"
expecteof "$PROG -f $xml -p //bbb[0]" 0 "" "^nodeset:0:<bbb x=\"hello\"><ccc>42</ccc></bbb>$"

new "xpath //bbb[ccc=99]"
expecteof "$PROG -f $xml -p //bbb[ccc=99]" 0 "" "^nodeset:0:<bbb x=\"bye\"><ccc>99</ccc></bbb>$"

new "xpath ../connection-type = 'responder-only'"
expecteof "$PROG -f $xml2 -p ../connection-type='responder-only' -i /aaa/bbb/here" 0 "" "^bool:true$"

new "xpath ../connection-type = 'no-responder'"
expecteof "$PROG -f $xml2 -p ../connection-type='no-responder' -i /aaa/bbb/here" 0 "" "^bool:false$"

new "xpath . <= 0.75 * ../max-rtr-adv-interval"
expecteof "$PROG -f $xml2 -i /aaa/bbb/here" 0 ". <= 0.75 * ../max-rtr-adv-interval" "^bool:true$"

new "xpath . > 0.75 * ../max-rtr-adv-interval"
expecteof "$PROG -f $xml2 -i /aaa/bbb/here" 0 ". > 0.75 * ../max-rtr-adv-interval" "^bool:false$"

new "xpath . <= ../valid-lifetime"
expecteof "$PROG -f $xml2 -i /aaa/bbb/here" 0 ". <= ../valid-lifetime" "^bool:true$"

new "xpath ../../rt:address-family = 'v6ur:ipv6-unicast'"
expecteof "$PROG -f $xml2 -i /aaa/bbb/here" 0 "../../rt:address-family = 'v6ur:ipv6-unicast'" "^bool:true$"

new "xpath ../../../rt:address-family = 'v6ur:ipv6-unicast'"
expecteof "$PROG -f $xml2 -i /aaa/bbb/here2/here" 0 "../../../rt:address-family = 'v6ur:ipv6-unicast'" "^bool:true$"

new "xpath /if:interfaces/if:interface[if:name=current()/rt:name]/ip:ipv6/ip:enabled='true'"
expecteof "$PROG -f $xml2" 0 "/if:interfaces/if:interface[if:name=current()/rt:name]/ip:ipv6/ip:enabled='true'" "^bool:true$"

new "xpath rt:address-family='v6ur:ipv6-unicast'"
expecteof "$PROG -f $xml2 -i /aaa" 0 "rt:address-family='v6ur:ipv6-unicast'" "^bool:true$"

new "xpath ../type='rt:static'"
expecteof "$PROG -f $xml2 -i /aaa/bbb/here" 0 "../type='rt:static'" "^bool:true$"

new "xpath rib-name != ../../name"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "rib-name != ../../name" "^bool:true$"

new "xpath routing/ribs/rib[name=current()/rib-name]/address-family=../../address-family"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "routing/ribs/rib[name=current()/rib-name]/address-family=../../address-family" "^bool:true$"

new "xpath ifType = \"ethernet\" or ifMTU = 1500"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" or ifMTU = 1500" "^bool:true$"

new "xpath ifType != \"ethernet\" or ifMTU = 1500"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" or ifMTU = 1500" "^bool:true$"

new "xpath ifType = \"ethernet\" or ifMTU = 1400"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" or ifMTU = 1400" "^bool:true$"

new "xpath ifType != \"ethernet\" or ifMTU = 1400"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" or ifMTU = 1400" "^bool:false$"

new "xpath ifType = \"ethernet\" and ifMTU = 1500"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" and ifMTU = 1500" "^bool:true$"

new "xpath ifType != \"ethernet\" and ifMTU = 1500"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" and ifMTU = 1500" "^bool:false$"

new "xpath ifType = \"ethernet\" and ifMTU = 1400"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "ifType = \"ethernet\" and ifMTU = 1400" "^bool:false$"

new "xpath ifType != \"ethernet\" and ifMTU = 1400"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "ifType != \"ethernet\" and ifMTU = 1400" "^bool:false$"

new "xpath ifType != \"atm\" or (ifMTU <= 17966 and ifMTU >= 64)"
expecteof "$PROG -f $xml2 -i /aaa/bbb" 0 "ifType != \"atm\" or (ifMTU <= 17966 and ifMTU >= 64)" "^bool:true$"

rm -rf $dir
