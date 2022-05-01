#!/usr/bin/env bash

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=snmp

if [ ${WITH_NETSNMP} != "yes" ]; then
    echo "Skipping test, Net-SNMP support not enabled."
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

snmpd=$(type -p snmpd)
snmpget="$(type -p snmpget) -On -c public -v2c localhost:1161 "
snmpset="$(type -p snmpset) -On -c public -v2c localhost:1161 "
snmptable="$(type -p snmptable) -c public -v2c localhost:1161 "

cfg=$dir/conf_startup.xml
fyang=$dir/clixon-example.yang

# AgentX unix socket
SOCK=/tmp/clixon_snmp.sock

# OID
OID=".1.3.6.1.4.1.8072.2.2.1"
OID_SET="${OID}.1.2.6.115.110.109.112.118.51"

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/var/tmp/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_SNMP_AGENT_SOCK>unix:$SOCK</CLICON_SNMP_AGENT_SOCK>
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

    new "Starting $snmpd --rwcommunity=public --master=agentx --agentXSocket=unix:/tmp/clixon_snmp.sock udp:127.0.0.1:1161"

    # Dirty workaround for snmpd in Alpine
    if [ -f /.dockerenv ]; then
        $snmpd -C --rwcommunity=public --master=agentx --agentXSocket=unix:$SOCK udp:127.0.0.1:1161
    else
        $snmpd --rwcommunity=public --master=agentx --agentXSocket=unix:$SOCK udp:127.0.0.1:1161
    fi

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
    start_backend -s init -f $cfg

    # Kill old clixon_snmp, if any
    new "Terminating any old clixon_snmp processes"
    sudo killall clixon_snmp

    new "Starting clixon_snmp"
    start_snmp $cfg &

    # Wait for things to settle
    sleep 3
}

function testexit(){
    sudo killall snmpd
    stop_snmp
}

new "SNMP table tests"
testinit

new "Test SNMP table for netSnmpIETFWGTable"
expectpart "$($snmptable $OID)" 0 "SNMP table: NET-SNMP-EXAMPLES-MIB::netSnmpIETFWGTable"

new "Set new value for one cell"
expectpart "$($snmpset $OID_SET s newstring)" 0 "$OID_SET = STRING: \"newstring\""

new "Test invalid type"
expectpart "$($snmpset $OID_SET u 1234)" 1

new "Test SNMP table for netSnmpIETFWGTable with new value"
expectpart "$($snmptable $OID)" 0 "newstring"

new "Cleaning up"
testexit

new "endtest"
endtest
