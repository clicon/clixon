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
snmpwalk="$(type -p snmpwalk) -On -c public -v2c localhost "
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
<!--        <sysUpTime>0</sysUpTime> -->
        <sysServices>72</sysServices>
    </system>
    <sysORTable>
        <sysOREntry>
            <sysORIndex>1</sysORIndex>
<!--            <sysORID>IP-MIB::ip</sysORID> -->
            <sysORDescr>Entry 1 description</sysORDescr>
<!--            <sysORUpTime>0</sysORUpTime> -->
        </sysOREntry>
        <sysOREntry>
            <sysORIndex>2</sysORIndex>
<!--            <sysORID>IF-MIB:if</sysORID> -->
            <sysORDescr>Entry 2 description</sysORDescr>
<!--            <sysORUpTime>0</sysORUpTime> -->
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

OID_SYS=".1.3.6.1.2.1.1"
OID_DESCR=".1.3.6.1.2.1.1.1"
OID_CONTACT=".1.3.6.1.2.1.1.4"
OID_LOCATION=".1.3.6.1.2.1.1.6"
OID_SYSNAME=".1.3.6.1.2.1.1.5"
OID_SERVICES=".1.3.6.1.2.1.1.7"
OID_ORTABLE=".1.3.6.1.2.1.1.9"

OID_ORTABLE1_IDX=".1.3.6.1.2.1.1.9.1.1.1"
OID_ORTABLE2_IDX=".1.3.6.1.2.1.1.9.1.1.2"
OID_ORTABLE1=".1.3.6.1.2.1.1.9.1.3.1"
OID_ORTABLE2=".1.3.6.1.2.1.1.9.1.3.2"

new "Get description, $OID_DESCR"
expectpart "$($snmpget $OID_DESCR)" 0 "$OID_DESCR = STRING: System description"

new "Get next $OID_DESCR"
expectpart "$($snmpgetnext $OID_DESCR)" 0 "$OID_CONTACT = STRING: clixon@clicon.com"

new "Get contact, $OID_CONTACT"
expectpart "$($snmpget $OID_CONTACT)" 0 "$OID_CONTACT = STRING: clixon@clicon.com"

new "Get next OID after contact $OID_CONTACT"
expectpart "$($snmpgetnext $OID_CONTACT)" 0 "$OID_SYSNAME = STRING: Test"

new "Get sysName $OID_SYSNAME"
expectpart "$($snmpget $OID_SYSNAME)" 0 "$OID_SYSNAME = STRING: Test"

new "Get next OID after sysName $OID_SYSNAME"
expectpart "$($snmpgetnext $OID_SYSNAME)" 0 "$OID_LOCATION = STRING: Clixon HQ"

new "Get sysLocation $OID_LOCATION"
expectpart "$($snmpget $OID_LOCATION)" 0 "$OID_LOCATION = STRING: Clixon HQ"

new "Get next OID after sysLocation $OID_LOCATION"
expectpart "$($snmpgetnext $OID_LOCATION)" 0 "$OID_SERVICES = INTEGER: 72"

new "Get sysServices $OID_SERVICES"
expectpart "$($snmpget $OID_SERVICES)" 0 "$OID_SERVICES = INTEGER: 72"

new "Get next OID after sysServices $OID_SERVICES"
expectpart "$($snmpgetnext $OID_SERVICES)" 0 "$OID_ORTABLE1_IDX = INTEGER: 1"

new "Get first index of OR table $OID_ORTABLE1_IDX"
expectpart "$($snmpget $OID_ORTABLE1_IDX)" 0 "$OID_ORTABLE1_IDX = INTEGER: 1"

new "Get next OID after index $OID_ORTABLE1_IDX"
expectpart "$($snmpgetnext $OID_ORTABLE1_IDX)" 0 "$OID_ORTABLE2_IDX = INTEGER: 2"

new "Get second index $OID_ORTABLE2_IDX"
expectpart "$($snmpget $OID_ORTABLE2_IDX)" 0 "$OID_ORTABLE2_IDX = INTEGER: 2"

new "Get sysORTable, entry 1 $OID_ORTABLE1"
expectpart "$($snmpget $OID_ORTABLE1)" 0 "STRING: Entry 1 description"

new "Get sysORTable, entry 2 $OID_ORTABLE2"
expectpart "$($snmpget $OID_ORTABLE2)" 0 "STRING: Entry 2 description"

new "Get table sysORTable $OID_ORTABLE"
expectpart "$($snmptable $OID_ORTABLE)" 0 ".*Entry 1 description.*"
expectpart "$($snmptable $OID_ORTABLE)" 0 ".*Entry 2 description.*"

new "Cleaning up"
testexit

new "endtest"
endtest
