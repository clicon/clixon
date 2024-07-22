#!/usr/bin/env bash
# SNMP notifications (SNMP v2 traps) MIB test

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Re-use main example backend state callbacks
APPNAME=example

if [ ${ENABLE_NETSNMP} != "yes" ]; then
    echo "Skipping test, Net-SNMP support not enabled."
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

: ${PERIOD:=2}

cfg=$dir/conf.xml
fyang=$dir/stream.yang

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
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_SNMP_AGENT_SOCK>unix:$SOCK</CLICON_SNMP_AGENT_SOCK>
  <CLICON_SNMP_MIB>example</CLICON_SNMP_MIB>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
  <CLICON_STREAM_DISCOVERY_RFC5277>true</CLICON_STREAM_DISCOVERY_RFC5277>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_STREAM_PATH>streams</CLICON_STREAM_PATH>
  <CLICON_STREAM_RETENTION>60</CLICON_STREAM_RETENTION>
</clixon-config>
EOF

cat <<EOF > $fyang
module example {
   namespace "urn:example:clixon";
   prefix ex;
   import ietf-yang-smiv2 {
      prefix "smiv2";
   }
   organization "Example, Inc.";
   contact "support at example.com";
   description "Example Notification Data Model Module.";
   revision "2016-07-07" {
      description "Initial version.";
      reference "example.com document 2-9976.";
   }
   notification event {
      smiv2:oid "1.3.6.1.4.1.8072.200.1";
      description "Example notification event.";
      leaf event-class {
         smiv2:oid "1.3.6.1.4.1.8072.200.1.1";
         type string;
         description "Event class identifier.";
      }
      container reportingEntity {
         smiv2:oid "1.3.6.1.4.1.8072.200.1.2";
         description "Event specific information.";
         leaf card {
            smiv2:oid "1.3.6.1.4.1.8072.200.1.2.1";
            type string;
            description "Line card identifier.";
         }
      }
      leaf severity {
         smiv2:oid "1.3.6.1.4.1.8072.200.1.3";
         type string;
         description "Event severity description.";
      }
   }
   container state {
      config false;
      description "state data for the example application (must be here for example get operation)";
      leaf-list op {
         type string;
      }
   }
}
EOF

function testinit(){
    new "test params: -s init -f $cfg -- -n ${PERIOD}"
    if [ $BE -ne 0 ]; then
    # Kill old backend and start a new one
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err "Failed to start backend"
    fi

    sudo pkill -f clixon_backend

    new "Starting backend"
    start_backend -s init -f $cfg -- -n ${PERIOD}
    fi

    new "wait backend"
    wait_backend

    if [ $SN -ne 0 ]; then
        # Kill old clixon_snmp, if any
        new "Terminating any old clixon_snmp processes"
        sudo killall -q clixon_snmp
        
        new "Starting clixon_snmp"
        # XXX augmented objects seem to be registered twice: error: duplicate registration: MIB modules snmpSetSerialNo and AgentX subagent 52, session 0x562087a70e20, subsession 0x562087a820c0 (oid .1.3.6.1.6.3.1.1.6.1).

        start_snmp $cfg
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

new "SNMP tests"
testinit


new "Start snmptrapd and listen for traps - expect 2-3 notifications"
ret=$(timeout 6s snmptrapd -f -Ot -Lo -F\"%#v\\n\")
expect="DISMAN-EVENT-MIB::sysUpTimeInstance = [0-9]*, SNMPv2-MIB::snmpTrapOID.0 = OID: NET-SNMP-MIB::netSnmp.200.1, NET-SNMP-MIB::netSnmp.200.1.1 = STRING: \"fault\", NET-SNMP-MIB::netSnmp.200.1.2.1 = STRING: \"Ethernet0\", NET-SNMP-MIB::netSnmp.200.1.3 = STRING: \"major\""
match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "Cleaning up"
testexit

rm -rf $dir

new "endtest"
endtest
