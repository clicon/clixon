#!/usr/bin/env bash
# snmpset. This requires deviation of MIB-YANG to make write operations
# Get default value, set new value via SNMP and check it, set new value via NETCONF and check
# Selected types from CLIXON/IF-MIB/ENTITY mib
# Also an incomplete commit failed test

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

if [ ${ENABLE_NETSNMP} != "yes" ]; then
    echo "Skipping test, Net-SNMP support not enabled."
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

snmpd=$(type -p snmpd)
snmpget="$(type -p snmpget) -On -c public -v2c localhost "
snmpset="$(type -p snmpset) -On -c public -v2c localhost "

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
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_SNMP_AGENT_SOCK>unix:$SOCK</CLICON_SNMP_AGENT_SOCK>
  <CLICON_SNMP_MIB>CLIXON-TYPES-MIB</CLICON_SNMP_MIB>
  <CLICON_SNMP_MIB>IF-MIB</CLICON_SNMP_MIB>
  <CLICON_SNMP_MIB>ENTITY-MIB</CLICON_SNMP_MIB>
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
  import CLIXON-TYPES-MIB {
      prefix "clixon-types";
  }
  import IF-MIB {
      prefix "if-mib";
  }
  import ENTITY-MIB {
      prefix "entity-mib";
  }
  deviation "/clixon-types:CLIXON-TYPES-MIB" {
     deviate replace {
        config true;
     }
  }
  deviation "/if-mib:IF-MIB" {
     deviate replace {
        config true;
     }
  }
  deviation "/entity-mib:ENTITY-MIB" {
     deviate replace {
        config true;
     }
  }
}
EOF

if true; then  # Dont start with a state (default)
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
</${DATASTORE_TOP}>
EOF

else # Start with a state (debug)

cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
  <CLIXON-TYPES-MIB xmlns="urn:ietf:params:xml:ns:yang:smiv2:CLIXON-TYPES-MIB">
     <clixonExampleScalars>
        <clixonExampleInteger>42</clixonExampleInteger>
        <ifIpAddr>4.3.2.1</ifIpAddr>
     </clixonExampleScalars>
  </CLIXON-TYPES-MIB>
  <IF-MIB xmlns="urn:ietf:params:xml:ns:yang:smiv2:IF-MIB">
    <ifStackTable>      
      <ifStackEntry>    
        <ifStackHigherLayer>9</ifStackHigherLayer>
        <ifStackLowerLayer>9</ifStackLowerLayer>
      </ifStackEntry>   
    </ifStackTable> 
    <ifTable>
      <ifEntry>
        <ifIndex>1</ifIndex>
        <ifPhysAddress>aa:bb:cc:dd:ee:ff</ifPhysAddress>
      </ifEntry>
    </ifTable>  
  </IF-MIB>
</${DATASTORE_TOP}>
EOF
fi

function testinit(){
    new "test params: -s startup -f $cfg"

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
        start_snmp $cfg
    fi

    new "wait snmp"
    wait_snmp
}

# Set value via SNMP, read value via SNMP and CLI
# Args:
# 1: name
# 2: type    
# 3: value   SNMP value
# 4: value2   SNMP value2 (as shown "after" snmpset)
# 5: xvalue  XML/Clixon value
# 6: OID in 
# 7: OID out
function testrun()
{
    name=$1
    type=$2
    value=$3
    value2=$4
    xvalue=$5
    oid_in=$6
    oid_out=$7

    # Type from man snmpset 
    case $type in
        "INTEGER")
            set_type="i"
            ;;
        "STRING")
            set_type="s"
            ;;
        "HEX STRING")
            set_type="x"
            ;;
        "TIMETICKS")
            set_type="t"
            ;;
        "IPADDRESS")
            set_type="a"
            ;;
        "OBJID")
            set_type="o"
            ;;
        "BITS")
            set_type="b"
            ;;
        *)
            set_type="s"
            ;;
    esac

    new "Set $name via SNMP"
    if [ $type == "STRING" ]; then
        echo "$snmpset $oid_in $set_type $value"
        expectpart "$($snmpset $oid_in $set_type $value)" 0 "$type:" "$value"
    else
        echo "$snmpset $oid_in $set_type $value2"
        expectpart "$($snmpset $oid_in $set_type $value)" 0 "$type: $value2"
    fi

    new "Check $name via SNMP"
    if [ "$type" == "STRING" ]; then
        expectpart "$($snmpget $oid_out)" 0 "$type:" "$value"
    else
        expectpart "$($snmpget $oid_out)" 0 "$type: $value2"
    fi

    new "Check $name via CLI"
    expectpart "$($clixon_cli -1 -f $cfg show config xml)" 0 "<$name>$xvalue</$name>"    
}

function testexit(){
    stop_snmp

    if [ $BE -ne 0 ]; then
        new "Kill backend"
        # Check if premature kill
        pid=$(pgrep -u root -f clixon_backend)
        if [ -z "$pid" ]; then
            err "backend already dead"
        fi
        # kill backend
        stop_backend -f $cfg
    fi
}

new "SNMP tests"
testinit

MIB=".1.3.6.1.4.1.8072.200"
IFMIB=".1.3.6.1.2.1"
ENTMIB=".1.3.6.1.2.1.47.1.1.1"

testrun clixonExampleInteger INTEGER 1234 1234 1234 ${MIB}.1.1.0 ${MIB}.1.1.0
testrun clixonExampleSleeper INTEGER -1 -1 -1 ${MIB}.1.2.0 ${MIB}.1.2.0
testrun clixonExampleString STRING foobar foobar foobar ${MIB}.1.3.0 ${MIB}.1.3.0
testrun ifPromiscuousMode INTEGER 1 1 true ${MIB}.1.10.0  ${MIB}.1.10.0 # boolean
testrun ifIpAddr IPADDRESS 1.2.3.4 1.2.3.4 1.2.3.4 ${MIB}.1.13.0  ${MIB}.1.13.0 # InetAddress
# XXX It was supposed to test writing hardware address type, but it is also read-only
#testrun ifPhysAddress STRING ff:ee:dd:cc:bb:aa ff:ee:dd:cc:bb:aa ff:ee:dd:cc:bb:aa ${IFMIB}.2.2.1.6.1

# Inline testrun for rowstatus complicated logic
name=ifStackStatus
type=INTEGER
oid=${IFMIB}.31.1.2.1.3.5.9

new "Set $name via SNMP"
expectpart "$($snmpset $oid i 4)" 0 "$type: createAndGo(4)"

new "Check $name via SNMP"
expectpart "$($snmpget $oid)" 0 "$type: active(1)"

new "Check $name via CLI"
expectpart "$($clixon_cli -1 -f $cfg show config xml)" 0 "<$name>active</$name>"    

# restart backend with synthetic validation failure
# Incomplete commit failed test: the commit fails by logging but this is not actually checked
if [ $BE -ne 0 ]; then
    # Kill old backend and start a new one
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err "Failed to start backend"
    fi
    
    sudo pkill -f clixon_backend
    
    new "Starting backend"
    start_backend -s startup -f $cfg -- -V CLIXON-TYPES-MIB/clixonExampleScalars/clixonExampleInteger
fi

new "wait backend"
wait_backend

new "set value with error"
expectpart "$($snmpset ${MIB}.1.1.0  i 4321 2>&1)" 2 "commitFailed"

new "Cleaning up"
testexit

rm -rf $dir

new "endtest"
endtest
