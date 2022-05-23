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
  <CLICON_SNMP_MIB>CLIXON-TYPES-MIB</CLICON_SNMP_MIB>
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
  <netSnmpExampleScalars>
    <netSnmpExampleInteger>0x7fffffff</netSnmpExampleInteger>
    <netSnmpExampleSleeper>-1</netSnmpExampleSleeper>
    <netSnmpExampleString>This is not default</netSnmpExampleString>
    <ifTableLastChange>12345678</ifTableLastChange>
    <ifType>modem</ifType>
    <ifSpeed>123123123</ifSpeed>
    <ifAdminStatus>testing</ifAdminStatus>
    <ifInOctets>123456</ifInOctets>
    <ifHCInOctets>4294967296</ifHCInOctets>
    <ifPromiscuousMode>true</ifPromiscuousMode>
    <ifCounterDiscontinuityTime>1234567890</ifCounterDiscontinuityTime>
    <ifStackStatus>active</ifStackStatus>
  </netSnmpExampleScalars>
  <netSnmpIETFWGTable>
    <netSnmpIETFWGEntry>
      <nsIETFWGName>index</nsIETFWGName>
      <nsIETFWGChair1>Name1</nsIETFWGChair1>
      <nsIETFWGChair2>Name2</nsIETFWGChair2>
    </netSnmpIETFWGEntry>
  </netSnmpIETFWGTable>
  <netSnmpHostsTable>
    <netSnmpHostsEntry>
      <netSnmpHostName>test</netSnmpHostName>
      <netSnmpHostAddressType>ipv4</netSnmpHostAddressType>
      <netSnmpHostAddress>10.20.30.40</netSnmpHostAddress>
      <netSnmpHostStorage>permanent</netSnmpHostStorage>
      <netSnmpHostRowStatus>active</netSnmpHostRowStatus>
    </netSnmpHostsEntry>
  </netSnmpHostsTable>
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

# NET-SNMP-EXAMPLES-MIB::netSnmpExamples
MIB=".1.3.6.1.4.1.8072.2"
OID1="${MIB}.1.1"      # netSnmpExampleInteger
OID2="${MIB}.1.2"      # netSnmpExampleSleeper
OID3="${MIB}.1.3"      # netSnmpExampleString
OID4="${MIB}.1.4"      # ifTableLastChange
OID5="${MIB}.1.5"      # ifType
OID6="${MIB}.1.6"      # ifSpeed
OID7="${MIB}.1.7"      # ifAdminStatus
OID8="${MIB}.1.8"      # ifInOctets
OID9="${MIB}.1.9"      # ifHCInOctets
OID10="${MIB}.1.10"    # ifPromiscuousMode
OID11="${MIB}.1.11"    # ifCounterDiscontinuityTime
OID12="${MIB}.1.12"    # ifStackStatus
OID13="${MIB}.2.1"     # netSnmpIETFWGTable
OID14="${MIB}.2.1.1"   # netSnmpIETFWGEntry
OID15="${MIB}.2.1.1.1" # nsIETFWGName
OID16="${MIB}.2.1.1.2" # nsIETFWGChair1
OID17="${MIB}.2.1.1.3" # nsIETFWGChair2
OID18="${MIB}.2.2"     # netSnmpHostsTable
OID19="${MIB}.2.2.1.1" # netSnmpHostName
OID20="${MIB}.2.2.1.2" # netSnmpHostAddressType
OID21="${MIB}.2.2.1.3" # netSnmpHostAddress
OID22="${MIB}.2.2.1.4" # netSnmpHostStorage
OID23="${MIB}.2.2.1.5" # netSnmpHostRowStatus


new "$snmpget"

new "Test SNMP get netSnmpExampleInteger"
expectpart "$($snmpget $OID1)" 0 "$OID1 = INTEGER: 2147483647"

new "Test SNMP getnext netSnmpExampleInteger"
expectpart "$($snmpgetnext $OID1)" 0 "$OID2 = INTEGER: -1"

new "Test SNMP get netSnmpExampleSleeper"
expectpart "$($snmpget $OID2)" 0 "$OID2 = INTEGER: -1"

new "Test SNMP getnext netSnmpExampleSleeper"
expectpart "$($snmpgetnext $OID2)" 0 "$OID3 = STRING: This is not default"

new "Test SNMP get netSNmpExampleString"
expectpart "$($snmpget $OID3)" 0 "$OID3 = STRING: This is not default" --not-- "fish"

new "Test SNMP getnext netSnmpExampleString"
expectpart "$($snmpgetnext $OID3)" 0 ""

new "Test SNMP get ipTableLastChnage"
expectpart "$($snmpget $OID4)" 0 "$OID4 = Gauge32: 12345678"

new "Test SNMP getnext ipTableLastChnage"
expectpart "$($snmpgetnext $OID4)" 0 ""

new "Test SNMP get ifType"
expectpart "$($snmpget $OID5)" 0 "$OID5 = INTEGER: 48"

new "Test SNMP getnext ifType"
expectpart "$($snmpgetnext $OID5)" 0 ""

new "Test SNMP get ifSpeed"
expectpart "$($snmpget $OID6)" 0 "$OID6 = Gauge32: 123123123"

new "Test SNMP getnext ifSpeed"
expectpart "$($snmpgetnext $OID6)" 0 ""

new "Test SNMP get ifAdminStatus"
expectpart "$($snmpget $OID7)" 0 "$OID7 = INTEGER: 3"

new "Test SNMP getnext ifAdminStatus"
expectpart "$($snmpgetnext $OID7)" 0 ""

new "Test SNMP get ifInOnctets"
expectpart "$($snmpget $OID8)" 0 "$OID8 = Gauge32: 123456"

new "Test SNMP getnext ifInOctets"
expectpart "$($snmpgetnext $OID8)" 0 ""

new "Test SNMP get ifHCInOctets"
expectpart "$($snmpget $OID9)" 0 "$OID9 = Counter64: 4294967296"

new "Test SNMP getnext ifHCInOctets"
expectpart "$($snmpgetnext $OID9)" 0 ""

new "Test SNMP get ifPromiscuousMode"
expectpart "$($snmpget $OID10)" 0 "$OID10 = INTEGER: 1"

new "Test SNMP getnext ifPromiscuousMode"
expectpart "$($snmpgetnext $OID10)" 0 ""

new "Test SNMP get ifCounterDiscontinuityTime"
expectpart "$($snmpget $OID11)" 0 "$OID11 = Gauge32: 1234567890"

new "Test SNMP getnext ifCounterDiscontinuityTime"
expectpart "$($snmpgetnext $OID11)" 0 ""

new "Test SNMP get ifStackStatus"
expectpart "$($snmpget $OID12)" 0 "$OID12 = INTEGER: 1"

new "Test SNMP getnext ifStackStatus"
expectpart "$($snmpgetnext $OID12)" 0 ""

new "Test SNMP table netSnmpIETFWGTable"
expectpart "$($snmptable $OID13)" 0 "Name1"

new "Test SNMP table netSnmpIETFWGTable"
expectpart "$($snmptable $OID13)" 0 "Name2"

new "Test SNMP getnext netSnmpIETFWGTable"
expectpart "$($snmpgetnext $OID13)" 0 ""

new "Test SNMP table netSnmpHostsTable"
expectpart "$($snmptable $OID18)" 0 "10.20.30.40" # Should verify all columns

new "Test SNMP getnext netSnmpHostsTable $OID18"
expectpart "$($snmpgetnext $OID18)" 0 ""

new "Cleaning up"
testexit

new "endtest"
endtest
