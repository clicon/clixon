#!/usr/bin/env bash
# SNMP table rowstatus tests

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

function testrun_createAndGo()
{
    index=go
    
    new "Configuring a value without a row is a failure"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'$index\' = 2 2>&1)" 2 "Reason: inconsistentValue"

    new "Set RowStatus to CreateAndGo and set tag"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\' = createAndGo SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'$index\' = 2)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = INTEGER: createAndGo(4)"
    
    new "Check rowstatus is active"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = INTEGER: active(1)"

    new "Get tag"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'$index\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyTag.'$index' = STRING: 2"

    new "Get tag via netconf: candidate"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/sn:SNMP-NOTIFICATION-MIB/sn:snmpNotifyTable/sn:snmpNotifyEntry[sn:snmpNotifyName='$index']/sn:snmpNotifyTag\" xmlns:sn=\"urn:ietf:params:xml:ns:yang:smiv2:SNMP-NOTIFICATION-MIB\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><SNMP-NOTIFICATION-MIB xmlns=\"urn:ietf:params:xml:ns:yang:smiv2:SNMP-NOTIFICATION-MIB\"><snmpNotifyTable><snmpNotifyEntry><snmpNotifyName>$index</snmpNotifyName><snmpNotifyTag>2</snmpNotifyTag></snmpNotifyEntry></snmpNotifyTable></SNMP-NOTIFICATION-MIB></data></rpc-reply>"

    new "Get tag via netconf: running"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/sn:SNMP-NOTIFICATION-MIB/sn:snmpNotifyTable/sn:snmpNotifyEntry[sn:snmpNotifyName='$index']/sn:snmpNotifyTag\" xmlns:sn=\"urn:ietf:params:xml:ns:yang:smiv2:SNMP-NOTIFICATION-MIB\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><SNMP-NOTIFICATION-MIB xmlns=\"urn:ietf:params:xml:ns:yang:smiv2:SNMP-NOTIFICATION-MIB\"><snmpNotifyTable><snmpNotifyEntry><snmpNotifyName>$index</snmpNotifyName><snmpNotifyTag>2</snmpNotifyTag></snmpNotifyEntry></snmpNotifyTable></SNMP-NOTIFICATION-MIB></data></rpc-reply>"

    new "set storage type"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.\'$index\' = 1)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.'$index' = INTEGER: other(1)"
}

function testrun_createAndWait()
{
    index=wait
    
    new "Configuring a value without a row is a failure"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'$index\' = 2 2>&1)" 2 "Reason: inconsistentValue"
    
    new "Set RowStatus to CreateAndWait and set tag"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\' = createAndWait SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'$index\' = 2)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = INTEGER: createAndWait(5)"

    new "Get tag"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'$index\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyTag.'$index' = STRING: 2"

    new "Get tag via netconf: candidate expect fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/sn:SNMP-NOTIFICATION-MIB/sn:snmpNotifyTable/sn:snmpNotifyEntry[sn:snmpNotifyName='$index']/sn:snmpNotifyTag\" xmlns:sn=\"urn:ietf:params:xml:ns:yang:smiv2:SNMP-NOTIFICATION-MIB\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

    new "Get rowstatus"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = INTEGER: notInService(2)"

    new "Set storagetype"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.\'$index\' = 1)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.'$index' = INTEGER: other(1)"

    new "Set rowstatus to active/ commit"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\' = active)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = INTEGER: active(1)"

    new "Set storagetype again"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.\'$index\' = 5)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyStorageType.'$index' = INTEGER: readOnly(5)"

    new "Set rowstatus to createAndWait"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\' = createAndWait)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = INTEGER: createAndWait(5)"

    new "Set second rowstatus to createAndGo"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'${index}2\' = createAndGo)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'${index}2' = INTEGER: createAndGo(4)"

    new "Set third rowstatus to createAndWait"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'${index}3\' = createAndWait)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'${index}3' = INTEGER: createAndWait(5)"

    new "Set third rowstatus to active"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'${index}3\' = active)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'${index}3' = INTEGER: active(1)"

    new "Get rowstatus"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = INTEGER: notInService(2)"
}

function testrun_removeRows()
{
    index=remove

    new "Set RowStatus to CreateAndGo and set tag"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\' = createAndGo SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'$index\' = 2)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = INTEGER: createAndGo(4)"

    new "Get tag"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'$index\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyTag.'$index' = STRING: 2"

    new "Get tag via netconf"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/sn:SNMP-NOTIFICATION-MIB/sn:snmpNotifyTable/sn:snmpNotifyEntry[sn:snmpNotifyName='$index']/sn:snmpNotifyTag\" xmlns:sn=\"urn:ietf:params:xml:ns:yang:smiv2:SNMP-NOTIFICATION-MIB\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><SNMP-NOTIFICATION-MIB xmlns=\"urn:ietf:params:xml:ns:yang:smiv2:SNMP-NOTIFICATION-MIB\"><snmpNotifyTable><snmpNotifyEntry><snmpNotifyName>$index</snmpNotifyName><snmpNotifyTag>2</snmpNotifyTag></snmpNotifyEntry></snmpNotifyTable></SNMP-NOTIFICATION-MIB></data></rpc-reply>"

    new "Set rowstatus to destroy"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\' = destroy)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = INTEGER: destroy(6)"

    new "Get rowstatus"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = No Such Instance currently exists at this OID"

    # Default value is ""
    new "Get tag"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyTag.\'$index\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyTag.'$index' = STRING: " --not-- "= STRING: 2" 

    new "Get tag via netconf: candidate expect fail"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/sn:SNMP-NOTIFICATION-MIB/sn:snmpNotifyTable/sn:snmpNotifyEntry[sn:snmpNotifyName='$index']/sn:snmpNotifyTag\" xmlns:sn=\"urn:ietf:params:xml:ns:yang:smiv2:SNMP-NOTIFICATION-MIB\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

    new "Set rowstatus to createandwait"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\' = createAndWait)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index'"
    
    new "Set rowstatus to destroy"
    expectpart "$($snmpset SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\' = destroy)" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = INTEGER: destroy(6)"

    new "Get rowstatus"
    expectpart "$($snmpget SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.\'$index\')" 0 "SNMP-NOTIFICATION-MIB::snmpNotifyRowStatus.'$index' = No Such Instance currently exists at this OID"
}

function testexit()
{
    stop_snmp
}

new "SNMP tests"
testinit

new "createAndGo"
testrun_createAndGo

new "createAndWait"
testrun_createAndWait

new "removeRows"
testrun_removeRows

new "Cleaning up"
testexit

new "endtest"
endtest
