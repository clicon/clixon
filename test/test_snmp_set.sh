#!/usr/bin/env bash
# snmpset. This requires deviation of MIB-YANG to make write operations
# Get default value, set new value via SNMP and check it, set new value via NETCONF and check

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=snmp

# XXX skip for now
if [ ${ENABLE_NETSNMP} != "yes" ]; then
    echo "Skipping test, Net-SNMP support not enabled."
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

snmpd=$(type -p snmpd)
snmpget="$(type -p snmpget) -On -c public -v2c localhost "
snmpset="$(type -p snmpset) -On -c public -v2c localhost "

cfg=$dir/conf_startup.xml
fyang=$dir/clixon-example.yang
fstate=$dir/state.xml

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
  <CLICON_SNMP_MIB>NET-SNMP-EXAMPLES-MIB</CLICON_SNMP_MIB>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import NET-SNMP-EXAMPLES-MIB {
      prefix "net-snmp-examples";
  }
  deviation "/net-snmp-examples:NET-SNMP-EXAMPLES-MIB" {
     deviate replace {
        config true;
     }
  }
}
EOF

# This is state data written to file that backend reads from (on request)
cat <<EOF > $fstate
   <sender-state xmlns="urn:example:example">
      <ref>x</ref>
   </sender-state>
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
	start_backend -s init -f $cfg
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
OID1="${MIB}.1.1"    # netSnmpExampleInteger
OID3="${MIB}.1.3"   # netSnmpExampleString

new "Test SNMP get for default value"
expectpart "$($snmpget $OID1)" 0 "$OID1 = INTEGER: 42"

new "Set new value to OID1"
expectpart "$($snmpset $OID1 i 1234)" 0 "$OID1 = INTEGER: 1234"

new "Get new value"
expectpart "$($snmpget $OID1)" 0 "$OID1 = INTEGER: 1234"

new "Set new value via NETCONF"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>none</default-operation><target><candidate/></target><config><NET-SNMP-EXAMPLES-MIB xmlns=\"urn:ietf:params:xml:ns:yang:smiv2:NET-SNMP-EXAMPLES-MIB\"><netSnmpExampleScalars><netSnmpExampleInteger>999</netSnmpExampleInteger></netSnmpExampleScalars></NET-SNMP-EXAMPLES-MIB></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Get new value"
expectpart "$($snmpget $OID1)" 0 "$OID1 = INTEGER: 999"

new "Test SNMP get string for default value"
expectpart "$($snmpget $OID3)" 0 "$OID3 = STRING: So long, and thanks for all the fish!."

new "Set new string value to OID3"
expectpart "$($snmpset $OID3 s foobar)" 0 "$OID3 = STRING: foobar"

new "Get new value"
expectpart "$($snmpget $OID3)" 0 "$OID3 = STRING: foobar"

new "Cleaning up"
testexit

new "endtest"
endtest
