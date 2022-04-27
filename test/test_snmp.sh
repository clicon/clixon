#!/usr/bin/env bash

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=snmp

# Dont run this test with valgrind
if [ $valgrindtest -ne 0 ]; then
    echo "...skipped "
    return 0 # skip
fi

if [ ${WITH_NETSNMP} != "yes" ]; then
    echo "Skipping test, Net-SNMP support not enabled."
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

snmpd=$(type -p snmpd)
snmpget="$(type -p snmpget) -c public -v2c localhost:1161 "
snmpset="$(type -p snmpset) -c public -v2c localhost:1161 "
clixon_snmp="/usr/local/sbin/clixon_snmp"
cfg=$dir/conf_startup.xml
fyang=$dir/clixon-example.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/var/tmp/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
}
EOF

function testinit(){
    # Kill old snmp daemon and start a new ones
    new "kill old snmp daemons"
    sudo killall snmpd

    new "Starting snmpd"
    $snmpd --rwcommunity=public --master=agentx --agentXSocket=unix:/tmp/clixon_snmp.sock udp:127.0.0.1:1161

    pgrep snmpd
    if [ $? != 0 ]; then
	err "Failed to start snmpd"
    fi

    # Kill old backend and start a new one
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	    err "Failed to start backend"
    fi

    sudo pkill -f clixon_backend

    new "Starting backend"
    start_backend -s init -f $cfg -- -s

    # Kill old clixon_snmp, if any
    new "Terminating any old clixon_snmp processes"
    sudo killall clixon_snmp

    new "Starting clixon_snmp"
    $clixon_snmp -f $cfg &

    sleep 1
    
    pgrep clixon_snmp
    if [ $? != 0 ]; then
	    err "Failed to start clixon_snmp"
    fi
}

function testexit(){
    sudo killall snmpd
}

new "SNMP tests"
testinit

new "Test SNMP get for default value"
expectpart "$($snmpget .1.3.6.1.4.1.8072.2.4.1.1.2.0)" 0 "NET-SNMP-EXAMPLES-MIB::netSnmpExamples.4.1.1.2.0 = INTEGER: 2"

new "Set new value to OID"
expectpart "$($snmpset .1.3.6.1.4.1.8072.2.4.1.1.2.0 i 1234)" 0 "NET-SNMP-EXAMPLES-MIB::netSnmpExamples.4.1.1.2.0 = INTEGER: 1234"

new "Get new value"
expectpart "$($snmpget .1.3.6.1.4.1.8072.2.4.1.1.2.0)" 0 "NET-SNMP-EXAMPLES-MIB::netSnmpExamples.4.1.1.2.0 = INTEGER: 1234"

new "Cleaning up"
testexit

new "endtest"
endtest
