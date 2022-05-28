#!/usr/bin/env bash
# SNMP "smoketest" Basic snmpget test for a scalar

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Re-use main example backend state callbacks
APPNAME=example

if [ ${ENABLE_NETSNMP} != "yes" ]; then
    echo "Skipping test, Net-SNMP support not enabled."
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

snmpd=$(type -p snmpd)
snmpget="$(type -p snmpget) -On -c public -v2c localhost "
snmpgetnext="$(type -p snmpgetnext) -On -c public -v2c localhost "
snmptable="$(type -p snmptable) -c public -v2c localhost "

cfg=$dir/conf_startup.xml
fyang=$dir/clixon-example.yang
fstate=$dir/state.xml

# AgentX unix socket
SOCK=/var/run/snmp.sock

# Relies on example_backend.so for $fstate file handling

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${MIB_GENERATED_YANG_DIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/var/tmp/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_SNMP_AGENT_SOCK>unix:$SOCK</CLICON_SNMP_AGENT_SOCK>
  <CLICON_SNMP_MIB>IF-MIB</CLICON_SNMP_MIB>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import IF-MIB {
      prefix "if-mib";
  }
}
EOF

# This is state data written to file that backend reads from (on request)
# integer and string have values, sleeper does not and uses default (=1)

cat <<EOF > $fstate
<IF-MIB xmlns="urn:ietf:params:xml:ns:yang:smiv2:IF-MIB">
  <interfaces>
    <ifNumber>1</ifNumber>
  </interfaces>
  <ifMIBObjects>
    <ifTableLastChange>0</ifTableLastChange>
    <ifStackLastChange>0</ifStackLastChange>
  </ifMIBObjects>
  <ifTable>
    <ifEntry>
      <ifIndex>1</ifIndex>
      <ifDescr>Test</ifDescr>
      <ifType>ethernetCsmacd</ifType>
      <ifMtu>1500</ifMtu>
      <ifSpeed>10000000</ifSpeed>
      <ifPhysAddress>aa:bb:cc:dd:ee:ff</ifPhysAddress>
      <ifAdminStatus>testing</ifAdminStatus>
      <ifOperStatus>up</ifOperStatus>
      <ifLastChange>0</ifLastChange>
      <ifInOctets>123</ifInOctets>
      <ifInUcastPkts>124</ifInUcastPkts>
      <ifInNUcastPkts>124</ifInNUcastPkts>
      <ifInDiscards>125</ifInDiscards>
      <ifInErrors>126</ifInErrors>
      <ifInUnknownProtos>127</ifInUnknownProtos>
      <ifOutOctets>128</ifOutOctets>
      <ifOutUcastPkts>129</ifOutUcastPkts>
      <ifOutNUcastPkts>129</ifOutNUcastPkts>
      <ifOutDiscards>130</ifOutDiscards>
      <ifOutErrors>131</ifOutErrors>
      <ifOutQLen>132</ifOutQLen>
      <ifSpecific>SNMPv2-SMI::zeroDotZero</ifSpecific>
    </ifEntry>
    <ifEntry>
      <ifIndex>2</ifIndex>
      <ifDescr>Test 2</ifDescr>
      <ifType>ethernetCsmacd</ifType>
      <ifMtu>1400</ifMtu>
      <ifSpeed>1000</ifSpeed>
      <ifPhysAddress>11:22:33:44:55:66</ifPhysAddress>
      <ifAdminStatus>down</ifAdminStatus>
      <ifOperStatus>down</ifOperStatus>
      <ifLastChange>0</ifLastChange>
      <ifInOctets>111</ifInOctets>
      <ifInUcastPkts>222</ifInUcastPkts>
      <ifInNUcastPkts>333</ifInNUcastPkts>
      <ifInDiscards>444</ifInDiscards>
      <ifInErrors>555</ifInErrors>
      <ifInUnknownProtos>666</ifInUnknownProtos>
      <ifOutOctets>777</ifOutOctets>
      <ifOutUcastPkts>888</ifOutUcastPkts>
      <ifOutNUcastPkts>999</ifOutNUcastPkts>
      <ifOutDiscards>101010</ifOutDiscards>
      <ifOutErrors>111111</ifOutErrors>
      <ifOutQLen>111</ifOutQLen>
      <ifSpecific>SNMPv2-SMI::zeroDotZero</ifSpecific>
    </ifEntry>
  </ifTable>
</IF-MIB>
EOF

# This is the expected result from snmpwalk:
#   $ snmpwalk -cpublic -v2c localhost IF-MIB::ifTable # .1.3.6.1.2.1.2.2
#   IF-MIB::ifIndex.1 = INTEGER: 1
#   IF-MIB::ifDescr.1 = STRING: Test
#   IF-MIB::ifType.1 = INTEGER: ethernetCsmacd(6)
#   IF-MIB::ifMtu.1 = INTEGER: 1500
#   IF-MIB::ifSpeed.1 = Gauge32: 10000000
#   IF-MIB::ifPhysAddress.1 = STRING: aa:bb:cc:dd:ee:ff
#   IF-MIB::ifAdminStatus.1 = INTEGER: up(1)
#   IF-MIB::ifOperStatus.1 = INTEGER: up(1)
#   IF-MIB::ifLastChange.1 = Timeticks: (0) 0:00:00.00
#   IF-MIB::ifInOctets.1 = Counter32: 123
#   IF-MIB::ifInUcastPkts.1 = Counter32: 123
#   IF-MIB::ifInNUcastPkts.1 = Counter32: 123
#   IF-MIB::ifInDiscards.1 = Counter32: 123
#   IF-MIB::ifInErrors.1 = Counter32: 123
#   IF-MIB::ifInUnknownProtos.1 = Counter32: 123
#   IF-MIB::ifOutOctets.1 = Counter32: 123
#   IF-MIB::ifOutUcastPkts.1 = Counter32: 123
#   IF-MIB::ifOutNUcastPkts.1 = Counter32: 123
#   IF-MIB::ifOutDiscards.1 = Counter32: 123
#   IF-MIB::ifOutErrors.1 = Counter32: 123
#   IF-MIB::ifOutQLen.1 = Gauge32: 123
#   IF-MIB::ifSpecific.1 = OID: SNMPv2-SMI::zeroDotZero

function testinit(){
    new "test params: -f $cfg -- -sS $fstate"
    if [ $BE -ne 0 ]; then
    # Kill old backend and start a new one
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err "Failed to start backend"
    fi

    sudo pkill -f clixon_backend

    new "Starting backend"
    start_backend -s init -f $cfg -- -sS $fstate
    fi

    new "wait backend"
    wait_backend

    if [ $CS -ne 0 ]; then
    # Kill old clixon_snmp, if any
    new "Terminating any old clixon_snmp processes"
    sudo killall -q clixon_snmp

    new "Starting clixon_snmp"
    start_snmp $cfg &
    fi

    new "wait snmp"
    wait_snmp
}

function testexit(){
    stop_snmp
}

new "SNMP tests"
testinit

# IF-MIB::interfaces
MIB=".1.3.6.1.2.1"
for (( i=1; i<23; i++ )); do
    eval OID${i}="${MIB}.2.2.1.$i.1"
done

new "$snmpget"

new "Test SNMP get all entries in ifTable"

new "Test $OID1 ifIndex"
expectpart "$($snmpget $OID1)" 0 "$OID1 = INTEGER: 1"

new "Test $OID2 ifDescr"
expectpart "$($snmpget $OID2)" 0 "$OID2 = STRING: Test"

new "Test $OID3 ifType"
expectpart "$($snmpget $OID3)" 0 "$OID3 = INTEGER: ethernetCsmacd(6)"

new "Test $OID4 ifMtu"
expectpart "$($snmpget $OID4)" 0 "$OID4 = INTEGER: 1500"

new "Test $OID5 ifSpeed"
expectpart "$($snmpget $OID5)" 0 "$OID5 = Gauge32: 10000000"

new "Test $OID6 ifPhysAddress yang:phys-address"
expectpart "$($snmpget $OID6)" 0 "$OID6 = STRING: aa.bb:cc:dd:ee:ff"

new "Test $OID7 ifAdminStatus"
expectpart "$($snmpget $OID7)" 0 "$OID7 = INTEGER: testing(3)"

new "Test $OID8 ifOperStatus"
expectpart "$($snmpget $OID8)" 0 "$OID8 = INTEGER: up(1)"

new "Test $OID9 ifLastChange"
expectpart "$($snmpget $OID9)" 0 "$OID9 = Timeticks: (0) 0:00:00.00"

new "Test $OID10 ifInOctets"
expectpart "$($snmpget $OID10)" 0 "$OID10 = Counter32: 123"

new "Test $OID11 ifInUcastPkts"
expectpart "$($snmpget $OID11)" 0 "$OID11 = Counter32: 124"

new "Test $OID12 ifInNUcastPkts"
expectpart "$($snmpget $OID12)" 0 "$OID12 = Counter32: 124"

new "Test $OID13 ifInDiscards"
expectpart "$($snmpget $OID13)" 0 "$OID13 = Counter32: 125"

new "Test $OID14 ifInErrors"
expectpart "$($snmpget $OID14)" 0 "$OID14 = Counter32: 126"

new "Test $OID15 ifInUnknownProtos"
expectpart "$($snmpget $OID15)" 0 "$OID15 = Counter32: 127"

new "Test $OID16 ifOutOctets"
expectpart "$($snmpget $OID16)" 0 "$OID16 = Counter32: 128"

new "Test $OID17 ifOutUcastPkts"
expectpart "$($snmpget $OID17)" 0 "$OID17 = Counter32: 129"

new "Test $OID18 ifOutNUcastPkts"
expectpart "$($snmpget $OID18)" 0 "$OID18 = Counter32: 129"

new "Test $OID19 ifOutDiscards"
expectpart "$($snmpget $OID19)" 0 "$OID19 = Counter32: 130"

new "Test $OID20 ifOutErrors"
expectpart "$($snmpget $OID20)" 0 "$OID20 = Counter32: 131"

new "Test $OID21 ifOutQLen"
expectpart "$($snmpget $OID21)" 0 "$OID21 = Gauge32: 132"

new "Test $OID22 ifSpecific"
expectpart "$($snmpget $OID22)" 0 "$OID22 = OID: .0.0"

new "Test ifTable"
expectpart "$($snmptable IF-MIB::ifTable)" 0 "Test 2" "1400" "1000" "11:22:33:44:55:66" "down" "111" "222" "333" "444" "555" "666" "777" "888" "999" "101010" "111111" "111"

new "Cleaning up"
testexit

new "endtest"
endtest
