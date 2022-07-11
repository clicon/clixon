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
  <CLICON_SNMP_MIB>CLIXON-TYPES-MIB</CLICON_SNMP_MIB>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import CLIXON-TYPES-MIB {
      prefix "clixon-types";
  }
}
EOF

# This is state data written to file that backend reads from (on request)
# integer and string have values, sleeper does not and uses default (=1)

cat <<EOF > $fstate
<CLIXON-TYPES-MIB xmlns="urn:ietf:params:xml:ns:yang:smiv2:CLIXON-TYPES-MIB">
  <clixonExampleScalars>
    <clixonExampleInteger>0x7fffffff</clixonExampleInteger>
    <clixonExampleSleeper>-1</clixonExampleSleeper>
    <clixonExampleString>This is not default</clixonExampleString>
    <ifTableLastChange>12345</ifTableLastChange>
    <ifType>modem</ifType>
    <ifSpeed>123123123</ifSpeed>
    <ifAdminStatus>testing</ifAdminStatus>
    <ifInOctets>123456</ifInOctets>
    <ifHCInOctets>4294967296</ifHCInOctets>
    <ifPromiscuousMode>true</ifPromiscuousMode>
    <ifCounterDiscontinuityTime>1234567890</ifCounterDiscontinuityTime>
    <ifStackStatus>active</ifStackStatus>
  </clixonExampleScalars>
  <clixonIETFWGTable>
    <clixonIETFWGEntry>
      <nsIETFWGName>42</nsIETFWGName>
      <nsIETFWGChair1>Name1</nsIETFWGChair1>
      <nsIETFWGChair2>Name2</nsIETFWGChair2>
    </clixonIETFWGEntry>
  </clixonIETFWGTable>
  <clixonHostsTable>
    <clixonHostsEntry>
      <clixonHostName>test</clixonHostName>
      <clixonHostAddressType>ipv4</clixonHostAddressType>
      <clixonHostAddress>10.20.30.40</clixonHostAddress>
      <clixonHostStorage>permanent</clixonHostStorage>
      <clixonHostRowStatus>active</clixonHostRowStatus>
    </clixonHostsEntry>
  </clixonHostsTable>
  <clixonInetTable>
    <clixonInetEntry>
      <clixonAddress>1.2.3.4</clixonAddress>
      <clixonString>foo</clixonString>
    </clixonInetEntry>
    <clixonInetEntry>
      <clixonAddress>2.2.2.2</clixonAddress>
      <clixonString>bar</clixonString>
    </clixonInetEntry>
  </clixonInetTable>
</CLIXON-TYPES-MIB>
EOF

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

MIB=".1.3.6.1.4.1.8072.200"
OID1="${MIB}.1.1"      # netSnmpExampleInteger
OID2="${MIB}.1.2"      # netSnmpExampleSleeper
OID3="${MIB}.1.3"      # netSnmpExampleString
OID4="${MIB}.1.4"      # ifTableLastChange 12345678
OID5="${MIB}.1.5"      # ifType modem(48)
OID6="${MIB}.1.6"      # ifSpeed 123123123
OID7="${MIB}.1.7"      # ifAdminStatus testing(3)
OID8="${MIB}.1.8"      # ifInOctets 123456
OID9="${MIB}.1.9"      # ifHCInOctets 4294967296
OID10="${MIB}.1.10"    # ifPromiscuousMode true(1)
OID11="${MIB}.1.11"    # ifCounterDiscontinuityTime 1234567890 TimeStamp
OID12="${MIB}.1.12"    # ifStackStatus active(1)
OID13="${MIB}.2.1"     # netSnmpIETFWGTable
OID14="${MIB}.2.1.1"   # netSnmpIETFWGEntry
OID15="${MIB}.2.1.1.1.42" # nsIETFWGName
OID16="${MIB}.2.1.1.2.42" # nsIETFWGChair1
OID17="${MIB}.2.1.1.3.42" # nsIETFWGChair2
OID18="${MIB}.2.2"     # netSnmpHostsTable
OID19="${MIB}.2.2.1.1.4.116.101.115.116" # netSnmpHostName
OID20="${MIB}.2.2.1.2.4.116.101.115.116" # netSnmpHostAddressType
OID21="${MIB}.2.2.1.3" # netSnmpHostAddress
OID22="${MIB}.2.2.1.4" # netSnmpHostStorage
OID23="${MIB}.2.2.1.5" # netSnmpHostRowStatus

NAME1="CLIXON-TYPES-MIB::clixonExampleInteger"
NAME2="CLIXON-TYPES-MIB::clixonExampleSleeper"
NAME3="CLIXON-TYPES-MIB::clixonExampleString"
NAME4="CLIXON-TYPES-MIB::ifTableLastChange"
NAME5="CLIXON-TYPES-MIB::ifType"
NAME6="CLIXON-TYPES-MIB::ifSpeed"
NAME7="CLIXON-TYPES-MIB::ifAdminStatus"
NAME8="CLIXON-TYPES-MIB::ifInOctets"
NAME9="CLIXON-TYPES-MIB::ifHCInOctets"
NAME10="CLIXON-TYPES-MIB::ifPromiscuousMode"
NAME11="CLIXON-TYPES-MIB::ifCounterDiscontinuityTime"
NAME12="CLIXON-TYPES-MIB::ifStackStatus"
NAME13="CLIXON-TYPES-MIB::netSnmpIETFWGTable"
NAME14="CLIXON-TYPES-MIB::netSnmpIETFWGEntry"
NAME15="CLIXON-TYPES-MIB::nsIETFWGName"
NAME16="CLIXON-TYPES-MIB::nsIETFWGChair1"
NAME17="CLIXON-TYPES-MIB::nsIETFWGChair2"
NAME18="CLIXON-TYPES-MIB::netSnmpHostsTable"
NAME19="CLIXON-TYPES-MIB::netSnmpHostName"
NAME20="CLIXON-TYPES-MIB::netSnmpHostAddressType"
NAME21="CLIXON-TYPES-MIB::netSnmpHostAddress"
NAME22="CLIXON-TYPES-MIB::netSnmpHostStorage"
NAME23="CLIXON-TYPES-MIB::netSnmpHostRowStatus"

new "$snmpget"

new "Get netSnmpExampleInteger"
validate_oid $OID1 $OID1 "INTEGER" 2147483647
validate_oid $OID1 $OID2 "INTEGER" -1
validate_oid $NAME1 $NAME1 "INTEGER" 2147483647
validate_oid $NAME1 $NAME2 "INTEGER" -1

new "Get netSnmpExampleSleeper"
validate_oid $OID2 $OID2 "INTEGER" -1
validate_oid $OID2 $OID3 "STRING" "\"This is not default\""
validate_oid $NAME2 $NAME2 "INTEGER" -1
validate_oid $NAME2 $NAME3 "STRING" "This is not default"

new "Get netSnmpExampleString"
validate_oid $OID3 $OID3 "STRING" "\"This is not default\""
validate_oid $OID3 $OID4 "Timeticks" "(12345) 0:02:03.45"
validate_oid $NAME3 $NAME3 "STRING" "This is not default"
validate_oid $NAME3 $NAME4 "Timeticks" "(12345) 0:02:03.45"

new "Get ifTableLastChange"
validate_oid $OID4 $OID4 "Timeticks" "(12345) 0:02:03.45"
validate_oid $OID4 $OID5 "INTEGER" 48
validate_oid $NAME4 $NAME4 "Timeticks" "(12345) 0:02:03.45"
validate_oid $NAME4 $NAME5 "INTEGER" "modem(48)"

new "Get ifType"
validate_oid $OID5 $OID5 "INTEGER" 48
validate_oid $OID5 $OID6 "Gauge32" 123123123
validate_oid $NAME5 $NAME5 "INTEGER" "modem(48)"
validate_oid $NAME5 $NAME6 "Gauge32" 123123123

new "Get ifSpeed"
validate_oid $OID6 $OID6 "Gauge32" 123123123
validate_oid $OID6 $OID7 "INTEGER" 3
validate_oid $NAME6 $NAME6 "Gauge32" 123123123
validate_oid $NAME6 $NAME7 "INTEGER" "testing(3)"

new "Get ifAdminStatus"
validate_oid $OID7 $OID7 "INTEGER" 3
validate_oid $OID7 $OID8 "Counter32" 123456
validate_oid $NAME7 $NAME7 "INTEGER" "testing(3)"
validate_oid $NAME7 $NAME8 "Counter32" 123456

new "Get ifInOctets"
validate_oid $OID8 $OID8 "Counter32" 123456
validate_oid $OID8 $OID9 "Counter64" 4294967296
validate_oid $NAME8 $NAME8 "Counter32" 123456
validate_oid $NAME8 $NAME9 "Counter64" 4294967296

new "Get ifInHCOctets"
validate_oid $OID9 $OID9 "Counter64" 4294967296
validate_oid $OID9 $OID10 "INTEGER" 1

validate_oid $NAME9 $NAME9 "Counter64" 4294967296
validate_oid $NAME9 $NAME10 "INTEGER" "true(1)"

new "Get ifPromiscuousMode"
validate_oid $OID10 $OID10 "INTEGER" 1
validate_oid $OID10 $OID11 "Timeticks" "(1234567890) 142 days, 21:21:18.90"
validate_oid $NAME10 $NAME10 "INTEGER" "true(1)"
validate_oid $NAME10 $NAME11 "Timeticks" "(1234567890) 142 days, 21:21:18.90"

new "Get ifCounterDiscontinuityTime"
validate_oid $OID11 $OID11 "Timeticks" "(1234567890) 142 days, 21:21:18.90"
validate_oid $OID11 $OID12 "INTEGER" 1
validate_oid $NAME11 $NAME11 "Timeticks" "(1234567890) 142 days, 21:21:18.90"
validate_oid $NAME11 $NAME12 "INTEGER" "active(1)"

new "Get ifStackStatus"
validate_oid $OID12 $OID12 "INTEGER" 1
validate_oid $NAME12 $NAME12 "INTEGER" "active(1)"

new "Get bulk OIDs"
expectpart "$($snmpbulkget $OID1)" 0 "$OID2 = INTEGER: -1" "$OID3 = STRING: \"This is not default\"" "$OID4 = Timeticks: (12345) 0:02:03.45" "$OID5 = INTEGER: 48" "$OID6 = Gauge32: 123123123" "$OID7 = INTEGER: 3" "$OID8 = Counter32: 123456" "$OID9 = Counter64: 4294967296" "$OID10 = INTEGER: 1" "$OID11 = Timeticks: (1234567890) 142 days, 21:21:18.90"

new "Test SNMP getnext netSnmpIETFWGTable"
validate_oid $OID15 $OID15 "INTEGER" 42

new "Test SNMP get nsIETFWGName"
validate_oid $OID15 $OID15 "INTEGER" 42

new "Test SNMP getnext nsIETFWGName"
expectpart "$($snmpgetnext $OID15)" 0 "Hex-STRING: 4E 61 6D 65 31 00"

new "Test SNMP getnext netSnmpHostsTable"
expectpart "$($snmpgetnext $OID18)" 0 "$OID19 = Hex-STRING: 74 65 73 74 00"

new "Test SNMP get netSnmpHostName"
expectpart "$($snmpget $OID19)" 0 "$OID19 = Hex-STRING: 74 65 73 74 00"

new "Test SNMP getnext netSnmpHostName"
expectpart "$($snmpgetnext $OID19)" 0 "$OID20 = INTEGER: 1"

new "Cleaning up"
testexit

new "endtest"
endtest
