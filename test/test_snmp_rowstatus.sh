#!/usr/bin/env bash
# SNMP table rowstatus tests
# 

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# XXX skip for now
if [ ${ENABLE_NETSNMP} != "yes" ]; then
    echo "Skipping test, Net-SNMP support not enabled."
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

snmpd=$(type -p snmpd)
snmpget="$(type -p snmpget) -c public -v2c localhost "
snmpset="$(type -p snmpset) -c public -v2c localhost "

cfg=$dir/conf.xml
fyang=$dir/clixon-example.yang

# AgentX unix socket
SOCK=/var/run/snmp.sock

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${MIB_GENERATED_YANG_DIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/var/tmp/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_SNMP_AGENT_SOCK>unix:$SOCK</CLICON_SNMP_AGENT_SOCK>
  <CLICON_SNMP_MIB>SNMP-NOTIFICATION-MIB</CLICON_SNMP_MIB>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import SNMP-NOTIFICATION-MIB {
      prefix "snmp-notification";
  }
  deviation "/snmp-notification:SNMP-NOTIFICATION-MIB" {
     deviate replace {
        config true;
     }
  }
}
EOF

cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
</${DATASTORE_TOP}>
EOF

function testinit(){
    new "test params: -f $cfg"

    if [ $BE -ne 0 ]; then
        # Kill old backend and start a new one
        new "kill old backend"
        sudo clixon_backend -zf $cfg
        if [ $? -ne 0 ]; then
            err "Failed to start backend"
        fi

        sudo pkill -f clixon_backend

        new "Starting backend"
        start_backend -s startup -f $cfg
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

function testrun_createAndGo()
{
    new "createAndGo"

    new "Configuring a value without a row is a failure"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'notify1\' = 2 2>&1)" 2 "Reason: inconsistentValue"

    new "Set RowStatus to CreateAndGo and set tag"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\' = createAndGo SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'notify1\' = 2)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify1' = INTEGER: createAndGo(4)"

    new "Rowstatus is active"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify1' = INTEGER: active(1)"

    new "Get tag"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'notify1\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyTag.'notify1' = STRING: 2"

    new "set storage type"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.\'notify1\' = 1)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.'notify1' = INTEGER: other(1)"
}

function testrun_createAndWait()
{
    new "createAndWait"

    new "Set RowStatus to CreateAndWait and set tag"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\' = createAndWait SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'notify1\' = 2)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify1' = INTEGER: createAndWait(5)"

    new "Get tag"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'notify1\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyTag.'notify1' = STRING: 2"

    new "Get rowstatus"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify1' = INTEGER: notInService(2)"

    new "Set storagetype"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.\'notify1\' = 1)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.'notify1' = INTEGER: other(1)"

    new "Set rowstatus to active/ commit"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\' = active)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify1' = INTEGER: active(1)"

    new "Set storagetype again"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.\'notify1\' = 5)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.'notify1' = INTEGER: readOnly(5)"

    new "Set rowstatus to createAndWait"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\' = createAndWait)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify1' = INTEGER: createAndWait(5)"

    new "Set second rowstatus to createAndGo"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify2\' = createAndGo)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify2' = INTEGER: createAndGo(4)"

    new "Set third rowstatus to createAndWait"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify3\' = createAndWait)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify3' = INTEGER: createAndWait(5)"

    new "Set third rowstatus to active"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify3\' = active)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify3' = INTEGER: active(1)"

    new "Get rowstatus"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify1' = INTEGER: notInService(2)"
}

function testrun_removeRows()
{
    new "removeRows"

    new "Set rowstatus to createandgo"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\' = createAndGo)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify1'"

    new "Set rowstatus to destroy"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\' = destroy)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify1' = destroy"

    new "Set rowstatus to destroy"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'notify1'"

    new "get rowstatus"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'notify1\')" 0 "No Such Instance currently exists at this OID)"
}

function testexit()
{
    stop_snmp
}

new "SNMP tests"
testinit

testrun_createAndGo

testrun_createAndWait

if $snmp_debug; then
    # NYI
    testrun_removeRows
fi

new "Cleaning up"
testexit

new "endtest"
endtest
