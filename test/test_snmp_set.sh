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
OID1="${MIB}.1.1"      # netSnmpExampleInteger
OID2="${MIB}.1.2"      # netSnmpExampleSleeper
OID3="${MIB}.1.3"      # netSnmpExampleString
OID4="${MIB}.1.4"      # ifTableLastChange
OID5="${MIB}.1.5"      # ifType
OID6="${MIB}.1.6"      # ifSpeed
OID7="${MIB}.1.7"      # ifAdminStatus
OID8="${MIB}.1.8"      # ifInOctets
OID9="${MIB}.1.9"      # ifHCInOctets NB 64-bit not tested and seems not supported
OID10="${MIB}.1.10"    # ifPromiscuousMode
OID11="${MIB}.1.11"    # ifCounterDiscontinuityTime
OID12="${MIB}.1.12"    # ifStackStatus
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

NAME=netSnmpExampleInteger
OID=$OID1
VALUE=1234
TYPE=INTEGER # Integer32

new "Get $NAME default"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: 42"

new "Set $NAME $VALUE"
expectpart "$($snmpset $OID i "$VALUE")" 0 "$OID = $TYPE: $VALUE"

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"
    
new "Set new value via NETCONF"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>none</default-operation><target><candidate/></target><config><CLIXON-TYPES-MIB xmlns=\"urn:ietf:params:xml:ns:yang:smiv2:CLIXON-TYPES-MIB\"><netSnmpExampleScalars><$NAME>999</$NAME></netSnmpExampleScalars></CLIXON-TYPES-MIB></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Get $NAME again"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: 999"

NAME=netSnmpExampleString
OID=$OID3
VALUE="foo bar"
TYPE=STRING # SnmpAdminString

new "Get $NAME default"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: So long, and thanks for all the fish!."

new "Set $NAME $VALUE"
expectpart "$($snmpset $OID s "$VALUE")" 0 "$OID = $TYPE: $VALUE"

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

NAME=ifTableLastChange
OID=$OID4
VALUE=12345 # (12345) 0:02:03.45
TYPE=TimeTicks

new "Get $NAME"
expectpart "$($snmpget $OID)" 0 "$OID = No Such Instance currently exists at this OID"

new "Set $NAME $VALUE"
expectpart "$($snmpset $OID t $VALUE)" 0 "$OID = $TYPE: ($VALUE) 0:02:03.45"

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: ($VALUE) 0:02:03.45"

NAME=ifType
OID=$OID5
VALUE=48 # modem(48)
TYPE=INTEGER # IANAifType /enum

new "Set $NAME $VALUE"
expectpart "$($snmpset $OID i $VALUE)" 0 "$OID = $TYPE: $VALUE"

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

NAME=ifSpeed
OID=$OID6
VALUE=123123123
TYPE=Gauge32

new "Set $NAME $VALUE"
expectpart "$($snmpset $OID u $VALUE)" 0 "$OID = $TYPE: $VALUE"

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

NAME=ifAdminStatus
OID=$OID7
VALUE=3 # testing(3)
TYPE=INTEGER

new "Set $NAME $VALUE"
expectpart "$($snmpset $OID i $VALUE)" 0 "$OID = $TYPE: $VALUE"

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

NAME=ifPromiscuousMode
OID=$OID10
VALUE=1 # true(1)
TYPE=INTEGER # TruthValue

new "Set $NAME $VALUE"
expectpart "$($snmpset $OID i $VALUE)" 0 "$OID = $TYPE: $VALUE"

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

NAME=ifCounterDiscontinuityTime
OID=$OID11
VALUE=1234567890
TYPE=Gauge32 # TimeStamp

new "Set $NAME $VALUE"
expectpart "$($snmpset $OID u $VALUE)" 0 "$OID = $TYPE: $VALUE"

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

NAME=ifStackStatus
OID=$OID12
VALUE=1 # active(1)
TYPE=INTEGER # RowStatus / enum

new "Set $NAME $VALUE"
expectpart "$($snmpset $OID i $VALUE)" 0 "$OID = $TYPE: $VALUE"

new "Get $NAME $VALUE"
expectpart "$($snmpget $OID)" 0 "$OID = $TYPE: $VALUE"

new "Cleaning up"
testexit

new "endtest"
endtest
