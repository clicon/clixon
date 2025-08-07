#!/usr/bin/env bash
# Netconf private candidate functionality
# See NETCONF and RESTCONF Private Candidate Datastores draft-ietf-netconf-privcand-07

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
tmp=$dir/tmp.x
fyang=$dir/clixon-example.yang

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-netconf:confirmed-commit</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-netconf-private-candidate:private-candidate</CLICON_FEATURE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_NETCONF_MESSAGE_ID_OPTIONAL>false</CLICON_NETCONF_MESSAGE_ID_OPTIONAL>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
  <CLICON_CLI_OUTPUT_FORMAT>cli</CLICON_CLI_OUTPUT_FORMAT>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   import ietf-interfaces {
        prefix if;
   }
   /* Example interface type for tests, local callbacks, etc */
   identity eth {
        base if:interface-type;
   }
}
EOF

new "test params: -f $cfg"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend  -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

## Test client and server capabilities

new "Client does not support private candidate"
expecteof "$clixon_netconf -ef $cfg " 255 "$DEFAULTHELLO" ""

PRIVCANDHELLO="<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTONLY><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:base:1.1</capability><capability>urn:ietf:params:netconf:capability:private-candidate:1.0</capability></capabilities></hello>]]>]]>"

new "Client supports private candidate. Server advertices resolution mode revert-on-conflict capability."
expecteof "$clixon_netconf -f $cfg" 0 "$PRIVCANDHELLO" \
"<capability>urn:ietf:params:netconf:capability:private-candidate:1.0?supported-resolution-modes=revert-on-conflict</capability>" "^$"

## Build test data

new "Build test data: netconf get-config empty candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "Build test data: netconf get-config single quotes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "Build test data: Add interf_one"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"${BASENS}\"><interface nc:operation=\"create\"><name>intf_one</name><description>Link to London</description><type xmlns:ex=\"urn:example:clixon\">ex:eth</type></interface></interfaces></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Build test data: Add interf_two"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"${BASENS}\"><interface nc:operation=\"create\"><name>intf_two</name><description>Link to Tokyo</description><type xmlns:ex=\"urn:example:clixon\">ex:eth</type></interface></interfaces></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Build test data: netconf get-config verify candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface xmlns:ex=\"urn:example:clixon\"><name>intf_one</name><description>Link to London</description><type>ex:eth</type></interface><interface xmlns:ex=\"urn:example:clixon\"><name>intf_two</name><description>Link to Tokyo</description><type>ex:eth</type></interface></interfaces></data></rpc-reply>"

new "Build test data: netconf get-config verify running empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "Build test data: netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Build test data: netconf get-config verify running"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface xmlns:ex=\"urn:example:clixon\"><name>intf_one</name><description>Link to London</description><type>ex:eth</type></interface><interface xmlns:ex=\"urn:example:clixon\"><name>intf_two</name><description>Link to Tokyo</description><type>ex:eth</type></interface></interfaces></data></rpc-reply>"

new "Spawn expect script"
# -d to debug matching info
sudo expect - "$clixon_netconf" "$cfg" $(whoami) <<'EOF'
# Use of expect to start two NETCONF sessions
log_user 0
set timeout 2
set clixon_netconf [lindex $argv 0]
set CFG [lindex $argv 1]
set USER [lindex $argv 2]

# Spawn first NETCONF session
spawn {*}sudo -u $USER clixon_netconf -f $CFG -- -e
set session_1 $spawn_id

# wait for hello message from server
expect {
    -i $session_1
    -re "revert-on-conflict.*]]>]]>" {}
    timeout { puts "timeout: No hello from server session 1"; exit 2 }
    eof { puts "1 eof: No hello from server session 1"; exit 3 }
}

# Spawn second NETCONF session
spawn {*}sudo -u $USER clixon_netconf -f $CFG -- -e
set session_2 $spawn_id

# wait for hello message from server
expect {
    -i $session_2
    -re "revert-on-conflict.*]]>]]>" {}
    timeout { puts "timeout: No hello from server session 2"; exit 2 }
    eof { puts "1 eof: No hello from server session 2"; exit 3 }
}

# send hello message without framing
set msg "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:capability:private-candidate:1.0</capability></capabilities></hello>]]>]]>\r"
send -i session_1 $msg
send -i session_2 $msg
sleep 1

# NETCONF rpc operation
proc rpc {session command reply} {
	send -i $session "<rpc message-id=\"42\" xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\">$command</rpc>]]>]]>\r"
	expect {
	    -i $session
	    -re "$reply.*</rpc-reply>.*]]>]]>" {}
	    timeout { puts "timeout: $command $reply"; exit 2 }
	    eof { puts "eof": $command $reply"; exit 3 }
	}
}

# Verify test data
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "London.*Tokyo"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "London.*Tokyo"

# 4.7.3.3.  Revert-on-conflict
# Session 1 edits the configuration
rpc $session_1 	"<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Link to San Francisco</description></interface></interfaces></config></edit-config>" "ok/"

# Session 2 edits the configuration
rpc $session_2 "<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name operation=\"delete\">intf_one</name></interface><interface><name>intf_two</name><description>Link to Paris</description></interface></interfaces></config></edit-config>" "ok/"

# TODO A conflict is detected, the update fails with an <rpc-error> and no merges/overwrite operations happen.
#rpc $session_1 "<update><resolution-mode>revert-on-conflict</resolution-mode></update>" "rpc-error"
# TODO Verify private candidates
#rpc $session_1 "<get-config><source><candidate/></source></get-config>" "Francisco.*Tokyo"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "Paris"

close $session_1
close $session_2
EOF

if [ $? -ne 0 ]; then
    err1 "Failed: test private candidate using expect"
fi


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

rm -rf $dir

new "endtest"
endtest
