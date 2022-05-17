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
}
EOF

# This is state data written to file that backend reads from (on request)
# integer and string have values, sleeper does not and uses default (=1)
cat <<EOF > $fstate
  <NET-SNMP-EXAMPLES-MIB xmlns="urn:ietf:params:xml:ns:yang:smiv2:NET-SNMP-EXAMPLES-MIB">
    <netSnmpExampleScalars>
      <netSnmpExampleInteger>42</netSnmpExampleInteger>
      <!--  netSnmpExampleSleeper>1</netSnmpExampleSleeper -->
      <netSnmpExampleString>This is not default</netSnmpExampleString>
    </netSnmpExampleScalars>
  </NET-SNMP-EXAMPLES-MIB>
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
OID1="${MIB}.1.1"   # netSnmpExampleInteger
OID2="${MIB}.1.2"   # netSnmpExampleSleeper
OID3="${MIB}.1.3"   # netSnmpExampleString

new "$snmpget"

new "Test SNMP get int"
expectpart "$($snmpget $OID1)" 0 "$OID1 = INTEGER: 42"

new "Test SNMP getnext int (should be sleeper)"
expectpart "$($snmpgetnext $OID1)" 0 "$OID2 = INTEGER: 1"

new "Test SNMP get sleeper (default)"
expectpart "$($snmpget $OID2)" 0 "$OID2 = INTEGER: 1"

new "Test SNMP getnext sleeper (expect string)"
expectpart "$($snmpgetnext $OID2)" 0 "$OID3 = STRING: This is not default"

new "Test SNMP get string"
expectpart "$($snmpget $OID3)" 0 "$OID3 = STRING: This is not default" --not-- "fish"

new "Test SNMP getnext string (expect heartbeat / no such object?)"
expectpart "$($snmpgetnext $OID3)" 0 "$OID3 = No more variables" # XXX this is a notification?

new "Cleaning up"
testexit

new "endtest"
endtest
