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
      <ifInDiscards>125</ifInDiscards>
      <ifInErrors>126</ifInErrors>   
      <ifInUnknownProtos>127</ifInUnknownProtos>
      <ifOutOctets>128</ifOutOctets>     
      <ifOutUcastPkts>129</ifOutUcastPkts>
      <ifOutDiscards>130</ifOutDiscards>
      <ifOutErrors>131</ifOutErrors>
      <ifOutQLen>132</ifOutQLen>
      <!-- ifSpecific>SNMPv2-SMI::zeroDotZero</ifSpecific--> <!-- objid type -->
    </ifEntry>
    <ifEntry>
      <ifIndex>2</ifIndex>
      <ifDescr>Test 2</ifDescr>
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
if false; then
OID1="${MIB}.2.2.1.1.1"
OID2="${MIB}.2.2.1.2.1"
OID3="${MIB}.2.2.1.3.1"
OID4="${MIB}.2.2.1.4.1"
OID5="${MIB}.2.2.1.5.1"
OID6="${MIB}.2.2.1.6.1"
OID7="${MIB}.2.2.1.7.1"
OID8="${MIB}.2.2.1.8.1"
OID9="${MIB}.2.2.1.9.1"
OID10="${MIB}.2.2.1.10.1"
OID11="${MIB}.2.2.1.11.1"
OID12="${MIB}.2.2.1.12.1"
OID13="${MIB}.2.2.1.13.1"
OID14="${MIB}.2.2.1.14.1"
OID15="${MIB}.2.2.1.15.1"
OID16="${MIB}.2.2.1.16.1"
OID17="${MIB}.2.2.1.17.1"
OID18="${MIB}.2.2.1.18.1"
OID19="${MIB}.2.2.1.19.1"
OID20="${MIB}.2.2.1.20.1"
OID21="${MIB}.2.2.1.21.1"
OID22="${MIB}.2.2.1.22.1"
fi

new "$snmpget"

new "Test SNMP get all entries in ifTable"

new "Test $OID2"
expectpart "$($snmpget $OID1)" 0 "$OID1 = INTEGER: 1"

new "Test $OID2"
expectpart "$($snmpget $OID2)" 0 "$OID2 = STRING: Test"

new "Test $OID3"
expectpart "$($snmpget $OID3)" 0 "$OID3 = INTEGER: ethernetCsmacd(6)"

new "Test $OID4"
expectpart "$($snmpget $OID4)" 0 "$OID4 = INTEGER: 1500"

new "Test $OID5"
expectpart "$($snmpget $OID5)" 0 "$OID5 = Gauge32: 10000000"

new "Test $OID6"
#expectpart "$($snmpget $OID6)" 0 "$OID6 = STRING: aa.bb:cc:dd:ee:ff"

new "Test $OID7"
expectpart "$($snmpget $OID7)" 0 "$OID7 = INTEGER: testing(3)"

new "Test $OID8"
expectpart "$($snmpget $OID8)" 0 "$OID8 = INTEGER: up(1)"

new "Test $OID9"
#expectpart "$($snmpget $OID9)" 0 "$OID9 = Timeticks: (0) 0:00:00.00"

new "Test $OID10"
expectpart "$($snmpget $OID10)" 0 "$OID10 = Counter32: 123"

new "Test $OID11"
expectpart "$($snmpget $OID11)" 0 "$OID11 = Counter32: 124"

new "Test $OID12"
#expectpart "$($snmpget $OID12)" 0 "$OID12 = Counter32: 125"

new "Test $OID13"
expectpart "$($snmpget $OID13)" 0 "$OID13 = Counter32: 125"

new "Test $OID14"
expectpart "$($snmpget $OID14)" 0 "$OID14 = Counter32: 126"

new "Test $OID15"
expectpart "$($snmpget $OID15)" 0 "$OID15 = Counter32: 127"

new "Test $OID16"
expectpart "$($snmpget $OID16)" 0 "$OID16 = Counter32: 128"

new "Test $OID17"
expectpart "$($snmpget $OID17)" 0 "$OID17 = Counter32: 129"

new "Test $OID18"
#expectpart "$($snmpget $OID18)" 0 "$OID18 = Counter32: 130"

new "Test $OID19"
expectpart "$($snmpget $OID19)" 0 "$OID19 = Counter32: 130"

new "Test $OID20"
expectpart "$($snmpget $OID20)" 0 "$OID20 = Counter32: 131"

new "Test $OID21"
expectpart "$($snmpget $OID21)" 0 "$OID21 = Gauge32: 132"

new "Test $OID22"
#expectpart "$($snmpget $OID22)" 0 "$OID22 = OID: SNMPv2-SMI::zeroDotZero"

new "Cleaning up"
testexit

new "endtest"
endtest
