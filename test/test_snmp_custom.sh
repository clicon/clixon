#!/usr/bin/env bash
# SNMP test for custom clixon extensions.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Re-use main example backend state callbacks
APPNAME=example

if [ ${ENABLE_NETSNMP} != "yes" ]; then
    echo "Skipping test, Net-SNMP support not enabled."
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

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
  <CLICON_SNMP_MIB>clixon-example</CLICON_SNMP_MIB>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import clixon-snmp {
    prefix cx-snmp;
  }
  import ietf-yang-smiv2 {
    prefix smiv2;
  }
  /* Generic config data */
    container table{
        smiv2:oid "1.3.6.1.2.1.47.1.1.1";
        list parameter{
            smiv2:oid "1.3.6.1.2.1.47.1.1.1.1";
            key name;
            cx-snmp:table-key "value";
            leaf name{
                type int32;
                smiv2:oid "1.3.6.1.2.1.47.1.1.1.1.1";
            }
            leaf value{
                type int32;
                smiv2:oid "1.3.6.1.2.1.47.1.1.1.1.2";
            }
            leaf hidden{
                type string;
            }
            leaf stat{
                description "Inline state data for example application";
                config false;
                type int32;
                smiv2:oid "1.3.6.1.2.1.47.1.1.1.1.3";
            }
        }
    }
}
EOF

# This is state data written to file that backend reads from (on request)
# integer and string have values, sleeper does not and uses default (=1)

cat <<EOF > $fstate
   <table xmlns="urn:example:clixon">
     <parameter>
       <name>1</name>
       <value>2</value>
       <hidden>3</hidden>
       <stat>4</stat>
     </parameter>
     <parameter>
       <name>11</name>
       <value>12</value>
       <hidden>13</hidden>
       <stat>14</stat>
     </parameter>
   </table>
EOF

function testinit(){
    new "test params: -s init -f $cfg -- -sS $fstate"
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

ENTITY_OID=".1.3.6.1.2.1.47.1.1.1"

# name, value=2
OID1="${ENTITY_OID}.1.1.2"
# name, value=12
OID2="${ENTITY_OID}.1.1.12"
# value, value=2
OID3="${ENTITY_OID}.1.2.2"
# value, value=12
OID4="${ENTITY_OID}.1.2.12"
# stat, value=2
OIDX="${ENTITY_OID}.1.3.2"
# stat, value=12
OIDY="${ENTITY_OID}.1.3.12"


new "SNMP system tests"
testinit
 
new "Get index, $OID1"
validate_oid $OID1 $OID1 "INTEGER" "1"

new "Get next $OID1"
validate_oid $OID1 $OID2 "INTEGER" "11"

new "Get index, $OID2"
validate_oid $OID2 $OID2 "INTEGER" "11"
new "Get next $OID2"
validate_oid $OID2 $OID3 "INTEGER" "2"

new "Get index, $OID3"
validate_oid $OID3 $OID3 "INTEGER" "2"

new "Get next $OID4"
validate_oid $OID3 $OID4 "INTEGER" "12"

new "Get index, $OID4"
validate_oid $OID4 $OID4 "INTEGER" "12"

new "Get next $OID4"
validate_oid $OID4 $OIDX "INTEGER" "4"

new "Get index, $OIDX"
validate_oid $OIDX $OIDX "INTEGER" "4"

new "Get next $OIDX"
validate_oid $OIDX $OIDY "INTEGER" "14"

new "Get index, $OIDY"
validate_oid $OIDY $OIDY "INTEGER" "14"

new "Cleaning up"
testexit

rm -rf $dir

new "endtest"
endtest
