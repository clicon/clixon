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
  <CLICON_SNMP_MIB>CLIXON-TYPES-MIB</CLICON_SNMP_MIB>
</clixon-config>
EOF

cat <<EOF > $fstate
<CLIXON-TYPES-MIB xmlns="urn:ietf:params:xml:ns:yang:smiv2:CLIXON-TYPES-MIB">
  <clixonExampleScalars>
    <clixonExampleInteger>0x7fffffff</clixonExampleInteger>
    <clixonExampleSleeper>-1</clixonExampleSleeper>
    <clixonExampleString>This is not default</clixonExampleString>
  </clixonExampleScalars>
  <clixonIETFWGTable>
    <clixonIETFWGEntry>
      <nsIETFWGName>index</nsIETFWGName>
      <nsIETFWGChair1>Name1</nsIETFWGChair1>
      <nsIETFWGChair2>Name2</nsIETFWGChair2>
    </clixonIETFWGEntry>
  </clixonIETFWGTable>
  <clixonHostsTable>
    <clixonHostsEntry>
      <clixonHostName>test</clixonHostName>
      <clixonHostAddressType>ipv4</clixonHostAddressType>
      <clixonHostAddress>10.20.30.40</clixonHostAddress>
      <clixonHostStorage>permanent</clixonHostStorage>
      <clixonHostRowStatus>active</clixonHostRowStatus>
    </clixonHostsEntry>
  </clixonHostsTable>
</CLIXON-TYPES-MIB>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import CLIXON-TYPES-MIB {
      prefix "clixon-types";
  }
  deviation "/clixon-types:CLIXON-TYPES-MIB" {
     deviate replace {
        config true;
     }
  }
}
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
MIB=".1.3.6.1.4.1.8072.200"
OID1="${MIB}.1.1"      # netSnmpExampleInteger
OID2="${MIB}.1.2"      # netSnmpExampleSleeper
OID3="${MIB}.1.3"      # netSnmpExampleString

OID15="${MIB}.2.1.1.1" # nsIETFWGName
OID16="${MIB}.2.1.1.2" # nsIETFWGChair1
OID17="${MIB}.2.1.1.3" # nsIETFWGChair2
OID18="${MIB}.2.2"     # netSnmpHostsTable
OID19="${MIB}.2.2.1.1" # netSnmpHostName
OID20="${MIB}.2.2.1.2" # netSnmpHostAddressType
OID21="${MIB}.2.2.1.3" # netSnmpHostAddress
OID22="${MIB}.2.2.1.4" # netSnmpHostStorage
OID23="${MIB}.2.2.1.5" # netSnmpHostRowStatus

new "Setting netSnmpExampleInteger"
validate_set $OID1 "INTEGER" 1234
validate_oid $OID1 $OID1 "INTEGER" 1234

new "Setting netSnmpExampleSleeper"
validate_set $OID2 "INTEGER" -1
validate_oid $OID2 $OID2 "INTEGER" -1

new "Set new value via NETCONF"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>none</default-operation><target><candidate/></target><config><CLIXON-TYPES-MIB xmlns=\"urn:ietf:params:xml:ns:yang:smiv2:CLIXON-TYPES-MIB\"><clixonExampleScalars><clixonExampleInteger>999</clixonExampleInteger></clixonExampleScalars></CLIXON-TYPES-MIB></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Validate value set from NETCONF"
validate_oid $OID1 $OID1 "INTEGER" 999

new "Setting netSnmpExampleString"
validate_oid $OID3 $OID3 "STRING" "\"So long, and thanks for all the fish!\""
validate_set $OID3 "STRING" "foo bar"
validate_oid $OID3 $OID3 "STRING" "\"foo bar\""

# new "Setting column nsIETFWGChair1"
# validate_set $OID16 "STRING" "asd"
# validate_oid $OID16 $OID16 "STRING" "asd"

# new "Setting column nsIETFWGChair2"
# validate_set $OID17 "STRING" "asd"
# validate_oid $OID17 $OID16 "STRING" "asdasd"

# new "Setting column netSnmpHostName"
# validate_set $OID19 "STRING" "asd"
# validate_oid $OID19 $OID19 "STRING" "asdasd"

# new "Setting netSnmpHostName"
# validate_set $OID20 "STRING" ipv6
# validate_oid $OID20 $OID20 "STRING" "asdasd"

new "Cleaning up"
testexit

new "endtest"
endtest
