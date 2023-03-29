#!/usr/bin/env bash
# SNMP test for yang union type with are same types of subtypes

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
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    
    import ietf-yang-smiv2 {
        prefix smiv2;
    }
    typedef first {
        type string{
        pattern
            "first"; 
        }
        description "first string";
    }
    typedef second {
        type string{
        pattern
            "second"; 
        }
        description "second string";
    }
    typedef third {
        type string{
        pattern
            "third"; 
        }
        description "third string";
    }

    /* Generic config data */
    container table{
        smiv2:oid "1.3.6.1.2.1.47.1.1.1";
        list parameter{
            smiv2:oid "1.3.6.1.2.1.47.1.1.1.1";
            key name;

            leaf name{
                type union{
                    type ex:first;
                    type ex:second;
                    type ex:third;
                }
                description "name";
                smiv2:oid "1.3.6.1.2.1.47.1.1.1.1.1";
            }
        }
    }
}
EOF

# This is state data written to file that backend reads from (on request)

cat <<EOF > $fstate
   <table xmlns="urn:example:clixon">
     <parameter>
       <name>first</name>
     </parameter>
     <parameter>
       <name>second</name>
     </parameter>
     <parameter>
       <name>third</name>
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

expectpart "$($snmpwalk)" 0 "0.0"

# first string, value=first
OID_FIRST="${ENTITY_OID}.1.1.1"
# second string, value=second
OID_SECOND="${ENTITY_OID}.1.1.2"
# third string, value=third
OID_THIRD="${ENTITY_OID}.1.1.3"

new "SNMP system tests"
testinit

# new "Get index, $OID_FIRST"
# validate_oid $OID_FIRST $OID_FIRST "STRING" "first"
# new "Get next $OID_FIRST"
# validate_oid $OID_FIRST $OID_SECOND "STRING" "second"
# new "Get index, $OID_SECOND"
# validate_oid $OID_SECOND $OID_SECOND "STRING" "second"
# new "Get next $OID_SECOND"
# validate_oid $OID_SECOND $OID_THIRD "STRING" "third"
# new "Get index, $OID_THIRD"
# validate_oid $OID_THIRD $OID_THIRD "STRING" "third"

new "Cleaning up"
testexit

rm -rf $dir

new "endtest"
endtest