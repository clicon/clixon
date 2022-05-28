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
    <ifTableLastChange>12345</ifTableLastChange>
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

NAME=netSnmpExampleInteger
OID=$OID1
VALUE=2147483647
TYPE=INTEGER # Integer32

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext netSnmpExampleInteger"
expectpart "$($snmpgetnext $OID1)" 0 "$OID2 = INTEGER: -1"

NAME=netSnmpExampleSleeper
OID=$OID2
VALUE=-1
TYPE=INTEGER # Integer32

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext netSnmpExampleSleeper"
expectpart "$($snmpgetnext $OID2)" 0 "$OID3 = STRING: This is not default"

NAME=netSnmpExampleString
OID=$OID3
VALUE="This is not default"
TYPE=STRING # SnmpAdminString

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext netSnmpExampleString"
expectpart "$($snmpgetnext $OID3)" 0 "$OID4 = Timeticks: (12345) 0:02:03.45"

NAME=ifTableLastChange
OID=$OID4
VALUE="(12345) 0:02:03.45"
TYPE=TimeTicks

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext ipTableLastChange"
expectpart "$($snmpgetnext $OID4)" 0 "$OID5 = INTEGER: 48"

NAME=ifType
OID=$OID5
VALUE=48 # modem(48)
TYPE=INTEGER # IANAifType /enum

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext ifType"
expectpart "$($snmpgetnext $OID5)" 0 "$OID6 = Gauge32: 123123123"

NAME=ifSpeed
OID=$OID6
VALUE=123123123
TYPE=Gauge32

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext ifSpeed"
expectpart "$($snmpgetnext $OID6)" 0 "$OID7 = INTEGER: 3"

NAME=ifAdminStatus
OID=$OID7
VALUE=3 # testing(3)
TYPE=INTEGER

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext ifAdminStatus"
expectpart "$($snmpgetnext $OID7)" 0 "$OID8 = Counter32: 123456"

NAME=ifInOctets
OID=$OID8
VALUE=123456
TYPE=Counter32

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext ifInOctets"
expectpart "$($snmpgetnext $OID8)" 0 "$OID9 = Counter64: 4294967296"

NAME=ifHCInOctets
OID=$OID9
VALUE=4294967296
TYPE=Counter64

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext ifHCInOctets"
expectpart "$($snmpgetnext $OID9)" 0 "$OID10 = INTEGER: 1"

NAME=ifPromiscuousMode
OID=$OID10
VALUE=1 # true(1)
TYPE=INTEGER # TruthValue

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext ifPromiscuousMode"
expectpart "$($snmpgetnext $OID10)" 0 "$OID11 = Gauge32: 1234567890"

NAME=ifCounterDiscontinuityTime
OID=$OID11
VALUE=1234567890
TYPE=Gauge32 # timestamp

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext ifCounterDiscontinuityTime"
expectpart "$($snmpgetnext $OID11)" 0 "$OID12 = INTEGER: 1"

NAME=ifStackStatus
OID=$OID12
VALUE=1 # active(1)
TYPE=INTEGER # RowStatus / enum

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Test SNMP getnext ifStackStatus"
expectpart "$($snmpgetnext $OID12)" 0 "" # XXX table OID

#----------------- table

# the index/key netSnmpHostName has type binary translates to string
# which requires a transaltion to numeric OID which is NYI
if false; then
new "Test SNMP table netSnmpIETFWGTable"
expectpart "$($snmptable $OID13)" 0 "Name1" "Name2"

new "Test SNMP getnext netSnmpIETFWGTable"
expectpart "$($snmpgetnext $OID13)" 0 ""

new "Test SNMP table netSnmpHostsTable"
expectpart "$($snmptable $OID18)" 0 "10.20.30.40" # Should verify all columns

new "Test SNMP getnext netSnmpHostsTable $OID18"
expectpart "$($snmpgetnext $OID18)" 0 ""

fi

new "Cleaning up"
testexit

new "endtest"
endtest
