#!/usr/bin/env bash
# SNMP system MIB test

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
snmpwalk="$(type -p snmpwalk) -On -c public -v2c localhost "
snmpwalkstr="$(type -p snmpwalk) -c public -v2c localhost "
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
  <CLICON_SNMP_MIB>SNMPv2-MIB</CLICON_SNMP_MIB>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import SNMPv2-MIB {
      prefix "snmpv2-mib";
  }
}
EOF

# This is state data written to file that backend reads from (on request)
# integer and string have values, sleeper does not and uses default (=1)

cat <<EOF > $fstate
<SNMPv2-MIB xmlns="urn:ietf:params:xml:ns:yang:smiv2:SNMPv2-MIB">
    <system>
        <sysName>Test</sysName>
        <sysContact>clixon@clicon.com</sysContact>
        <sysLocation>Clixon HQ</sysLocation>
        <sysDescr>System description</sysDescr>
        <sysUpTime>11223344</sysUpTime>
        <sysServices>72</sysServices>
    </system>
    <sysORTable>
        <sysOREntry>
            <sysORIndex>1</sysORIndex>
            <sysORID>1.3.6.1.2.1.4</sysORID>
            <sysORDescr>Entry 1 description</sysORDescr>
            <sysORUpTime>11223344</sysORUpTime>
        </sysOREntry>
        <sysOREntry>
            <sysORIndex>2</sysORIndex>
            <sysORID>1.3.6.1.2.1.2.2</sysORID>
            <sysORDescr>Entry 2 description</sysORDescr>
            <sysORUpTime>1122111111</sysORUpTime>
        </sysOREntry>
    </sysORTable>
</SNMPv2-MIB>
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

OID_SYS=".1.3.6.1.2.1.1"
OID_DESCR="${OID_SYS}.1"
OID_UPTIME="${OID_SYS}.3"
OID_CONTACT="${OID_SYS}.4"
OID_SYSNAME="${OID_SYS}.5"
OID_LOCATION="${OID_SYS}.6"
OID_SERVICES="${OID_SYS}.7"
OID_ORTABLE="${OID_SYS}.9"
OID_ORTABLE1_IDX="${OID_SYS}.9.1.1.1"
OID_ORTABLE2_IDX="${OID_SYS}.9.1.1.2"
OID_ORTABLE1="${OID_SYS}.9.1.3.1"
OID_ORTABLE2="${OID_SYS}.9.1.3.2"

NAME_DESCR="SNMPv2-MIB::sysDescr"
NAME_UPTIME="SNMPv2-MIB::sysUpTime"
NAME_CONTACT="SNMPv2-MIB::sysContact"
NAME_SYSNAME="SNMPv2-MIB::sysName"
NAME_LOCATION="SNMPv2-MIB::sysLocation"
NAME_SERVICES="SNMPv2-MIB::sysServices"
NAME_ORTABLE="SNMPv2-MIB::sysORTable"
NAME_ORTABLE1_IDX="SNMPv2-MIB::sysORIndex.1"
NAME_ORTABLE2_IDX="SNMPv2-MIB::sysORIndex.2"
NAME_ORTABLE1="SNMPv2-MIB::sysORDescr.1"
NAME_ORTABLE2="SNMPv2-MIB::sysORDescr.2"

new "Get description, $OID_DESCR"
validate_oid $OID_DESCR $OID_DESCR "STRING" "System description"
validate_oid $NAME_DESCR $NAME_DESCR "STRING" "System description"

new "Get next $OID_DESCR"
validate_oid $OID_DESCR $OID_UPTIME "Timeticks" "(11223344) 1 day, 7:10:33.44"
validate_oid $NAME_DESCR $NAME_UPTIME "Timeticks" "(11223344) 1 day, 7:10:33.44"

new "Get contact, $OID_CONTACT"
validate_oid $OID_CONTACT $OID_CONTACT "STRING" "clixon@clicon.com"
validate_oid $NAME_CONTACT $NAME_CONTACT "STRING" "clixon@clicon.com"

new "Get next OID after contact $OID_CONTACT"
validate_oid $OID_CONTACT  $OID_SYSNAME  "STRING" "Test"
validate_oid $NAME_CONTACT $NAME_SYSNAME "STRING" "Test"

new "Get sysName $OID_SYSNAME"
validate_oid $OID_SYSNAME $OID_SYSNAME "STRING" "Test"
validate_oid $NAME_SYSNAME $NAME_SYSNAME "STRING" "Test"

new "Get next OID after sysName $OID_SYSNAME"
validate_oid $OID_SYSNAME $OID_LOCATION "STRING" "Clixon HQ"
validate_oid $NAME_SYSNAME $NAME_LOCATION "STRING" "Clixon HQ"

new "Get sysLocation $OID_LOCATION"
validate_oid $OID_LOCATION $OID_LOCATION "STRING" "Clixon HQ"
validate_oid $NAME_LOCATION $NAME_LOCATION "STRING" "Clixon HQ"

new "Get next OID after sysLocation $OID_LOCATION"
validate_oid $OID_LOCATION $OID_SERVICES "INTEGER" 72
validate_oid $NAME_LOCATION $NAME_SERVICES "INTEGER" 72

new "Get sysServices $OID_SERVICES"
validate_oid $OID_SERVICES $OID_SERVICES "INTEGER" "72"
validate_oid $NAME_SERVICES $NAME_SERVICES "INTEGER" "72"

new "Get next OID after sysServices $OID_SERVICES"
validate_oid $OID_SERVICES $OID_ORTABLE1_IDX "INTEGER" 1
validate_oid $NAME_SERVICES $NAME_ORTABLE1_IDX "INTEGER" 1

new "Get first index of OR table $OID_ORTABLE1_IDX"
validate_oid $OID_ORTABLE1_IDX $OID_ORTABLE1_IDX "INTEGER" 1
validate_oid $NAME_ORTABLE1_IDX $NAME_ORTABLE1_IDX "INTEGER" 1

new "Get next OID after index $OID_ORTABLE1_IDX"
validate_oid $OID_ORTABLE1_IDX $OID_ORTABLE2_IDX "INTEGER" 2
validate_oid $NAME_ORTABLE1_IDX $NAME_ORTABLE2_IDX "INTEGER" 2

new "Get second index $OID_ORTABLE2_IDX"
validate_oid $OID_ORTABLE2_IDX $OID_ORTABLE2_IDX "INTEGER" 2
validate_oid $NAME_ORTABLE2_IDX $NAME_ORTABLE2_IDX "INTEGER" 2

new "Get sysORTable, entry 1 $OID_ORTABLE1"
validate_oid $OID_ORTABLE1 $OID_ORTABLE1 "STRING" "Entry 1 description"
validate_oid $NAME_ORTABLE1 $NAME_ORTABLE1 "STRING" "Entry 1 description"

new "Get sysORTable, entry 2 $OID_ORTABLE2"
validate_oid $OID_ORTABLE2 $OID_ORTABLE2 "STRING" "Entry 2 description"
validate_oid $NAME_ORTABLE2 $NAME_ORTABLE2 "STRING" "Entry 2 description"

new "Get table sysORTable $OID_ORTABLE"
expectpart "$($snmptable $OID_ORTABLE)" 0 ".*Entry 1 description.*" "IP-MIB::ip" "1:7:10:33.44"
expectpart "$($snmptable $OID_ORTABLE)" 0 ".*Entry 2 description.*" "IF-MIB::ifTable" "129:20:58:31.11"
expectpart "$($snmptable $NAME_ORTABLE)" 0 ".*Entry 1 description.*" "IP-MIB::ip" "1:7:10:33.44"
expectpart "$($snmptable $NAME_ORTABLE)" 0 ".*Entry 2 description.*" "IF-MIB::ifTable" "129:20:58:31.11"

new "Walk the tabbles..."
expectpart "$($snmpwalkstr system)" 0 "SNMPv2-MIB::sysDescr = STRING: System description." \
    "SNMPv2-MIB::sysUpTime = Timeticks: (11223344) 1 day, 7:10:33.44" \
    "SNMPv2-MIB::sysContact = STRING: clixon@clicon.com." \
    "SNMPv2-MIB::sysName = STRING: Test." \
    "SNMPv2-MIB::sysLocation = STRING: Clixon HQ." \
    "SNMPv2-MIB::sysServices = INTEGER: 72" \
    "SNMPv2-MIB::sysORIndex.1 = INTEGER: 1" \
    "SNMPv2-MIB::sysORIndex.2 = INTEGER: 2" \
    "SNMPv2-MIB::sysORID.1 = OID: IP-MIB::ip" \
    "SNMPv2-MIB::sysORID.2 = OID: IF-MIB::ifTable" \
    "SNMPv2-MIB::sysORDescr.1 = STRING: Entry 1 description." \
    "SNMPv2-MIB::sysORDescr.2 = STRING: Entry 2 description." \
    "SNMPv2-MIB::sysORUpTime.1 = Timeticks: (11223344) 1 day, 7:10:33.44" \
    "SNMPv2-MIB::sysORUpTime.2 = Timeticks: (1122111111) 129 days, 20:58:31.11"

new "Cleaning up"
testexit

new "endtest"
endtest
