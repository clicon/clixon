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
snmpwalk="$(type -p snmpwalk) -c public -v2c localhost "

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
  <CLICON_VALIDATE_STATE_XML>false</CLICON_VALIDATE_STATE_XML>
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
      <ifSpecific>0.0</ifSpecific>
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
      <ifSpecific>1.2.3</ifSpecific>
    </ifEntry>
  </ifTable>
  <ifRcvAddressTable>
    <ifRcvAddressEntry>
      <ifIndex>1</ifIndex>
      <ifRcvAddressAddress>11:bb:cc:dd:ee:ff</ifRcvAddressAddress>
      <ifRcvAddressStatus>active</ifRcvAddressStatus>
      <ifRcvAddressType>other</ifRcvAddressType>
    </ifRcvAddressEntry>
    <ifRcvAddressEntry>
      <ifIndex>2</ifIndex>
      <ifRcvAddressAddress>aa:22:33:44:55:66</ifRcvAddressAddress>
      <ifRcvAddressStatus>createAndGo</ifRcvAddressStatus>
      <ifRcvAddressType>volatile</ifRcvAddressType>
    </ifRcvAddressEntry>
  </ifRcvAddressTable>
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

    if [ $SN -ne 0 ]; then
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

OID24=".1.3.6.1.2.1.31.1.4.1.1.1.17.49.49.58.98.98.58.99.99.58.100.100.58.101.101.58.102.102"
OID25=".1.3.6.1.2.1.31.1.4.1.1.2.17.97.97.58.50.50.58.51.51.58.52.52.58.53.53.58.54.54"
OID26=".1.3.6.1.2.1.31.1.4.1.2.1.17.49.49.58.98.98.58.99.99.58.100.100.58.101.101.58.102.102"
OID27=".1.3.6.1.2.1.31.1.4.1.2.2.17.97.97.58.50.50.58.51.51.58.52.52.58.53.53.58.54.54"
OID28=".1.3.6.1.2.1.31.1.4.1.3.1.17.49.49.58.98.98.58.99.99.58.100.100.58.101.101.58.102.102"
OID29=".1.3.6.1.2.1.31.1.4.1.3.2.17.97.97.58.50.50.58.51.51.58.52.52.58.53.53.58.54.54"

NAME1="IF-MIB::ifIndex"
NAME2="IF-MIB::ifDescr"
NAME3="IF-MIB::ifType"
NAME4="IF-MIB::ifMtu"
NAME5="IF-MIB::ifSpeed"
NAME6="IF-MIB::ifPhysAddress"
NAME7="IF-MIB::ifAdminStatus"
NAME8="IF-MIB::ifOperStatus"
NAME9="IF-MIB::ifLastChange"
NAME10="IF-MIB::ifInOctets"
NAME11="IF-MIB::ifInUcastPkts"
NAME12="IF-MIB::ifInNUcastPkts"
NAME13="IF-MIB::ifInDiscards"
NAME14="IF-MIB::ifInErrors"
NAME15="IF-MIB::ifInUnknownProtos"
NAME16="IF-MIB::ifOutOctets"
NAME17="IF-MIB::ifOutUcastPkts"
NAME18="IF-MIB::ifOutNUcastPkts"
NAME19="IF-MIB::ifOutDiscards"
NAME20="IF-MIB::ifOutErrors"
NAME21="IF-MIB::ifOutQLen"
NAME22="IF-MIB::ifSpecific"

NAME24="IF-MIB::ifRcvAddressAddress.1.17.49.49.58.98.98.58.99.99.58.100.100.58.101.101.58.102.102"
NAME25="IF-MIB::ifRcvAddressAddress.2.17.97.97.58.50.50.58.51.51.58.52.52.58.53.53.58.54.54"
NAME26="IF-MIB::ifRcvAddressStatus.1.17.49.49.58.98.98.58.99.99.58.100.100.58.101.101.58.102.102"
NAME27="IF-MIB::ifRcvAddressStatus.2.17.97.97.58.50.50.58.51.51.58.52.52.58.53.53.58.54.54"
NAME28="IF-MIB::ifRcvAddressType.1.17.49.49.58.98.98.58.99.99.58.100.100.58.101.101.58.102.102"
NAME29="IF-MIB::ifRcvAddressType.2.17.97.97.58.50.50.58.51.51.58.52.52.58.53.53.58.54.54"

new "$snmpget"

new "Test SNMP get all entries in ifTable"

new "Test $OID1 ifIndex"
validate_oid $OID1 $OID1 "INTEGER" "1"
validate_oid "$NAME1.1" "$NAME1.1" "INTEGER" 1
validate_oid "$NAME1.1" "$NAME1.2" "INTEGER" 2

new "Test $OID2 ifDescr"
validate_oid $OID2 $OID2 "STRING" "Test"
validate_oid $NAME2.1 $NAME2.1 "STRING" "Test"
validate_oid $NAME2.2 $NAME2.2 "STRING" "Test"

new "Test $OID3 ifType"
validate_oid $OID3 $OID3 "INTEGER" "ethernetCsmacd(6)"
validate_oid $NAME3.1 $NAME3.1 "INTEGER" "ethernetCsmacd(6)"
validate_oid $NAME3.2 $NAME3.2 "INTEGER" "ethernetCsmacd(6)"

new "Test $OID4 ifMtu"
validate_oid $OID4 $OID4 "INTEGER" "1500"
validate_oid $NAME4.1 $NAME4.1 "INTEGER" 1500
validate_oid $NAME4.2 $NAME4.2 "INTEGER" 1400

new "Test $OID5 ifSpeed"
validate_oid $OID5 $OID5 "Gauge32" "10000000"
validate_oid $NAME5.1 $NAME5.1 "Gauge32" 10000000
validate_oid $NAME5.2 $NAME5.2 "Gauge32" 1000

new "Test $OID6 ifPhysAddress yang:phys-address"
validate_oid $OID6 $OID6 "STRING" "aa.bb:cc:dd:ee:ff"
validate_oid $NAME6.1 $NAME6.1 "STRING" "aa.bb:cc:dd:ee:ff"
validate_oid $NAME6.2 $NAME6.2 "STRING" "11:22:33:44:55:66"

new "Test $OID7 ifAdminStatus"
validate_oid $OID7 $OID7 "INTEGER" "testing(3)"
validate_oid $NAME7.1 $NAME7.1 "INTEGER" "testing(3)"
validate_oid $NAME7.2 $NAME7.2 "INTEGER" "down(2)"

new "Test $OID8 ifOperStatus"
validate_oid $OID8 $OID8 "INTEGER" "up(1)"
validate_oid $NAME8.1 $NAME8.1 "INTEGER" "up(1)"
validate_oid $NAME8.2 $NAME8.2 "INTEGER" "down(2)"

new "Test $OID9 ifLastChange"
validate_oid $OID9 $OID9 "Timeticks" "(0) 0:00:00.00"
validate_oid $NAME9.1 $NAME9.1 "Timeticks" "(0) 0:00:00.00"
validate_oid $NAME9.2 $NAME9.2 "Timeticks" "(0) 0:00:00.00"

new "Test $OID10 ifInOctets"
validate_oid $OID10 $OID10 "Counter32" 123
validate_oid $NAME10.1 $NAME10.1 "Counter32" 123
validate_oid $NAME10.2 $NAME10.2 "Counter32" 111

new "Test $OID11 ifInUcastPkts"
validate_oid $OID11 $OID11 "Counter32" 124
validate_oid $NAME11.1 $NAME11.1 "Counter32" 124
validate_oid $NAME11.2 $NAME11.2 "Counter32" 222

new "Test $OID12 ifInNUcastPkts"
validate_oid $OID12 $OID12 "Counter32" 124
validate_oid $NAME12.1 $NAME12.1 "Counter32" 124
validate_oid $NAME12.2 $NAME12.2 "Counter32" 333

new "Test $OID13 ifInDiscards"
validate_oid $OID13 $OID13 "Counter32" 125
validate_oid $NAME13.1 $NAME13.1 "Counter32" 125
validate_oid $NAME13.2 $NAME13.2 "Counter32" 444

new "Test $OID14 ifInErrors"
validate_oid $OID14 $OID14 "Counter32" 126
validate_oid $NAME14.1 $NAME14.1 "Counter32" 126
validate_oid $NAME14.2 $NAME14.2 "Counter32" 555

new "Test $OID15 ifInUnknownProtos"
validate_oid $OID15 $OID15 "Counter32" 127
validate_oid $NAME15.1 $NAME15.1 "Counter32" 127
validate_oid $NAME15.2 $NAME15.2 "Counter32" 666

new "Test $OID16 ifOutOctets"
validate_oid $OID16 $OID16 "Counter32" 128
validate_oid $NAME16.1 $NAME16.1 "Counter32" 128
validate_oid $NAME16.2 $NAME16.2 "Counter32" 777

new "Test $OID17 ifOutUcastPkts"
validate_oid $OID17 $OID17 "Counter32" 129
validate_oid $NAME17.1 $NAME17.1 "Counter32" 129
validate_oid $NAME17.2 $NAME17.2 "Counter32" 888

new "Test $OID18 ifOutNUcastPkts"
validate_oid $OID18 $OID18 "Counter32" 129
validate_oid $NAME18.1 $NAME18.1 "Counter32" 129
validate_oid $NAME18.2 $NAME18.2 "Counter32" 999

new "Test $OID19 ifOutDiscards"
validate_oid $OID19 $OID19 "Counter32" 130
validate_oid $NAME19.1 $NAME19.1 "Counter32" 130
validate_oid $NAME19.2 $NAME19.2 "Counter32" 101010

new "Test $OID20 ifOutErrors"
validate_oid $OID20 $OID20 "Counter32" 131
validate_oid $NAME20.1 $NAME20.1 "Counter32" 131
validate_oid $NAME20.2 $NAME20.2 "Counter32" 111111

new "Test $OID21 ifOutQLen"
validate_oid $OID21 $OID21 "Gauge32" 132
validate_oid $NAME21.1 $NAME21.1 "Gauge32" 132
validate_oid $NAME21.2 $NAME21.2 "Gauge32" 111

new "Test $OID22 ifSpecific"
validate_oid $OID22 $OID22 "OID" ".0.0"
validate_oid $NAME22.1 $NAME22.1 "OID" "SNMPv2-SMI::zeroDotZero"
validate_oid $NAME22.2 $NAME22.2 "OID" "iso.2.3"

new "Test ifTable"
expectpart "$($snmptable IF-MIB::ifTable)" 0 "Test 2" "1400" "1000" "11:22:33:44:55:66" "down" "111" "222" "333" "444" "555" "666" "777" "888" "999" "101010" "111111" "111"

new "Walk the walk..."
expectpart "$($snmpwalk IF-MIB::ifTable)" 0 "IF-MIB::ifIndex.1 = INTEGER: 1" \
           "IF-MIB::ifIndex.2 = INTEGER: 2" \
           "IF-MIB::ifDescr.1 = STRING: Test." \
           "IF-MIB::ifDescr.2 = STRING: Test 2." \
           "IF-MIB::ifType.1 = INTEGER: ethernetCsmacd(6)" \
           "IF-MIB::ifType.2 = INTEGER: ethernetCsmacd(6)" \
           "IF-MIB::ifMtu.1 = INTEGER: 1500" \
           "IF-MIB::ifMtu.2 = INTEGER: 1400" \
           "IF-MIB::ifSpeed.1 = Gauge32: 10000000" \
           "IF-MIB::ifSpeed.2 = Gauge32: 1000" \
           "IF-MIB::ifPhysAddress.1 = STRING: aa:bb:cc:dd:ee:ff" \
           "IF-MIB::ifPhysAddress.2 = STRING: 11:22:33:44:55:66" \
           "IF-MIB::ifAdminStatus.1 = INTEGER: testing(3)" \
           "IF-MIB::ifAdminStatus.2 = INTEGER: down(2)" \
           "IF-MIB::ifOperStatus.1 = INTEGER: up(1)" \
           "IF-MIB::ifOperStatus.2 = INTEGER: down(2)" \
           "IF-MIB::ifLastChange.1 = Timeticks: (0) 0:00:00.00" \
           "IF-MIB::ifLastChange.2 = Timeticks: (0) 0:00:00.00" \
           "IF-MIB::ifInOctets.1 = Counter32: 123" \
           "IF-MIB::ifInOctets.2 = Counter32: 111" \
           "IF-MIB::ifInUcastPkts.1 = Counter32: 124" \
           "IF-MIB::ifInUcastPkts.2 = Counter32: 222" \
           "IF-MIB::ifInNUcastPkts.1 = Counter32: 124" \
           "IF-MIB::ifInNUcastPkts.2 = Counter32: 333" \
           "IF-MIB::ifInDiscards.1 = Counter32: 125" \
           "IF-MIB::ifInDiscards.2 = Counter32: 444" \
           "IF-MIB::ifInErrors.1 = Counter32: 126" \
           "IF-MIB::ifInErrors.2 = Counter32: 555" \
           "IF-MIB::ifInUnknownProtos.1 = Counter32: 127" \
           "IF-MIB::ifInUnknownProtos.2 = Counter32: 666" \
           "IF-MIB::ifOutOctets.1 = Counter32: 128" \
           "IF-MIB::ifOutOctets.2 = Counter32: 777" \
           "IF-MIB::ifOutUcastPkts.1 = Counter32: 129" \
           "IF-MIB::ifOutUcastPkts.2 = Counter32: 888" \
           "IF-MIB::ifOutNUcastPkts.1 = Counter32: 129" \
           "IF-MIB::ifOutNUcastPkts.2 = Counter32: 999" \
           "IF-MIB::ifOutDiscards.1 = Counter32: 130" \
           "IF-MIB::ifOutDiscards.2 = Counter32: 101010" \
           "IF-MIB::ifOutErrors.1 = Counter32: 131" \
           "IF-MIB::ifOutErrors.2 = Counter32: 111111" \
           "IF-MIB::ifOutQLen.1 = Gauge32: 132" \
           "IF-MIB::ifOutQLen.2 = Gauge32: 111" \
           "IF-MIB::ifSpecific.1 = OID: SNMPv2-SMI::zeroDotZero" \
           "IF-MIB::ifSpecific.2 = OID: iso.2.3"

new "Test $OID24"
validate_oid $OID24 $OID24 "STRING" "11:bb:cc:dd:ee:ff"
validate_oid $NAME24 $NAME24 "STRING" "11:bb:cc:dd:ee:ff" "IF-MIB::ifRcvAddressAddress.1.\"11:bb:cc:dd:ee:ff\" = STRING: 11:bb:cc:dd:ee:ff"

new "Get next $OID24"
validate_oid $OID24 $OID25 "STRING" "aa:22:33:44:55:66"
validate_oid $NAME24 $NAME25 "STRING" "aa:22:33:44:55:66" "IF-MIB::ifRcvAddressAddress.2.\"aa:22:33:44:55:66\" = STRING: aa:22:33:44:55:66"

new "Get $NAME25"

validate_oid $OID25 $OID25 "STRING" "aa:22:33:44:55:66"
validate_oid $NAME25 $NAME25 "STRING" "aa:22:33:44:55:66" "IF-MIB::ifRcvAddressAddress.2.\"aa:22:33:44:55:66\" = STRING: aa:22:33:44:55:66"

new "Get next $OID25"

validate_oid $OID25 $OID26 "INTEGER" "active(1)"
validate_oid $NAME25 $NAME26 "INTEGER" "active(1)" "IF-MIB::ifRcvAddressStatus.1.\"11:bb:cc:dd:ee:ff\" = INTEGER: active(1)"

new "Get $OID26"

validate_oid $OID26 $OID26 "INTEGER" "active(1)"
validate_oid $NAME26 $NAME26 "INTEGER" "active(1)" "IF-MIB::ifRcvAddressStatus.1.\"11:bb:cc:dd:ee:ff\" = INTEGER: active(1)"

new "Get next $OID26"

validate_oid $OID26 $OID27 "INTEGER" "createAndGo(4)"
validate_oid $NAME26 $NAME27 "INTEGER" "createAndGo(4)" "IF-MIB::ifRcvAddressStatus.2.\"aa:22:33:44:55:66\" = INTEGER: createAndGo(4)"

new "Get $OID27"

validate_oid $OID27 $OID27 "INTEGER" "createAndGo(4)"
validate_oid $NAME27 $NAME27 "INTEGER" "createAndGo(4)" "IF-MIB::ifRcvAddressStatus.2.\"aa:22:33:44:55:66\" = INTEGER: createAndGo(4)"

new "Get next $OID27"

validate_oid $OID27 $OID28 "INTEGER" "other(1)"
validate_oid $NAME27 $NAME28 "INTEGER" "other(1)" "IF-MIB::ifRcvAddressType.1.\"11:bb:cc:dd:ee:ff\" = INTEGER: other(1)"

new "Get $OID28"

validate_oid $OID28 $OID28 "INTEGER" "other(1)"
validate_oid $NAME28 $NAME28 "INTEGER" "other(1)" "IF-MIB::ifRcvAddressType.1.\"11:bb:cc:dd:ee:ff\" = INTEGER: other(1)"

new "Get next $OID28"

validate_oid $OID28 $OID29 "INTEGER" "volatile(2)"
validate_oid $NAME28 $NAME29 "INTEGER" "volatile(2)" "IF-MIB::ifRcvAddressType.2.\"aa:22:33:44:55:66\" = INTEGER: volatile(2)"

new "Test ifTable"
expectpart "$($snmptable IF-MIB::ifRcvAddressTable)" 0 "SNMP table: IF-MIB::ifRcvAddressTable" "ifRcvAddressStatus" "ifRcvAddressType" "active" "other" "createAndGo" "volatile"

new "Walk ifRcvTable"
expectpart "$($snmpwalk IF-MIB::ifRcvAddressTable)" 0 "IF-MIB::ifRcvAddressAddress.1.\"11:bb:cc:dd:ee:ff\" = STRING: 11:bb:cc:dd:ee:ff" \
           "IF-MIB::ifRcvAddressAddress.2.\"aa:22:33:44:55:66\" = STRING: aa:22:33:44:55:66" \
           "IF-MIB::ifRcvAddressStatus.1.\"11:bb:cc:dd:ee:ff\" = INTEGER: active(1)" \
           "IF-MIB::ifRcvAddressStatus.2.\"aa:22:33:44:55:66\" = INTEGER: createAndGo(4)" \
           "IF-MIB::ifRcvAddressType.1.\"11:bb:cc:dd:ee:ff\" = INTEGER: other(1)" \
           "IF-MIB::ifRcvAddressType.2.\"aa:22:33:44:55:66\" = INTEGER: volatile(2)"

testexit

new "endtest"
endtest
