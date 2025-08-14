#!/usr/bin/env bash
### Netconf private candidate functionality
### See NETCONF and RESTCONF Private Candidate Datastores draft-ietf-netconf-privcand-07

## Test cases implemented
# 4.5.1 NETCONF server advertise private candidate capability according to runtime (startup) configuration
# 4.5.2 NETCONF client does not support private candidate. Verify that connection not possible.
# 4.7.5 Support revert-on-conflict resolution mode capability.
# 4.8.1.1 <update> operation by client without conflict: There is a change of any value
# 4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of any list entry
# 4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of a presence container
# 4.8.1.1 <update> operation by client without conflict: here is a change of any component member of a leaf-list
# 4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of a leaf
# 4.8.1.1 <update> operation by client without conflict: There is a change to the order of any list items in a list configured as "ordered-by user"
# 4.8.1.1 <update> operation by client without conflict: There is a change to the order of any items in a leaf-list configured as "ordered-by user"
# (4.8.1.1 <update> operation by client without conflict: There is a change to any YANG metadata associated with the node Note. metadata cannot be changed in Clixon.)
# 4.8.1.1.1 <resolution-mode> parameter> revert-on-conflict accepted
# 4.8.1.1.1 <resolution-mode> parameter revert-on-conflict is optional
# 4.8.1.1 <update> operation by client not ok, prefer-candidate conflict resolution.
# 4.8.1.1 <update> operation by client not ok, prefer-running conflict resolution

## TODO Test cases to be implemented
# 4.5.2 NETCONF client supports private candidate. Verify that each client uses its own private candidate.
# 4.5.3 RESTCONF client always operates on private candidate
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict. There is a change of any value
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of any list entry
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change to the order of any list items in a list configured as "ordered-by user"
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of a presence container
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of any component member of a leaf-list
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change to the order of any items in a leaf-list configured as "ordered-by user"
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of a leaf
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change to any YANG metadata associated with the node
# 4.8.1.1 <update> operation implicit by server not ok, prefer-candidate conflict resolution
# 4.8.1.1 <update> operation implicit by server not ok, prefer-running conflict resolution
# 4.8.2.1 <commit> implicit update failed with when revert-on-conflict resolution
# 4.8.2.1 <commit> implicit update ok
# 4.8.2.1.1 <confirned/> commit ok/canceled/timeout
# 4.8.2.2 <get-config> creates private candidate
# 4.8.2.2 <get-config> operates on private candidate
# 4.8.2.3 <edit-config> creates private candidate
# 4.8.2.3 <edit-config> operates on private candidate
# 4.8.2.4 <copy-config> creates private candidate
# 4.8.2.4 <copy-config> operates on private candidate
# 4.8.2.5 <get-data> creates private candidate
# 4.8.2.5 <get-data> operates on private candidate
# 4.8.2.6 <edit-data> creates private candidate
# 4.8.2.6 <edit-data> operates on private candidate
# 4.8.2.7 <compare> not supported !
# 4.8.2.8 <lock> operates on private candidate
# 4.8.2.9 <unlock> operates on private candidate
# 4.8.2.10 <delete-config> operates on private candidate
# 4.8.2.11 <discard-changes> operates on private candidate
# 4.8.2.12 <get> no private candidate
# 4.8.2.13 <cancel-commit>

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
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
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
   /* Example interface type for tests */
   identity eth {
        base if:interface-type;
   }
    list lu {
        key k;
        ordered-by user;
        leaf k {
            type string;
        }
    }
    leaf-list llu {
        type string;
        ordered-by user;
    }
    container table{
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
        }
    }
    leaf-list ll {
        type string;
    }
    leaf l {
        type string;
    }
}
EOF

new "test params: -f $cfg -s startup"
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
    <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
        <interface xmlns:ex="urn:example:clixon">
            <name>intf_one</name>
            <description>Link to London</description>
            <type>ex:eth</type>
        </interface>
        <interface xmlns:ex="urn:example:clixon">
            <name>intf_two</name>
            <description>Link to Tokyo</description>
            <type>ex:eth</type>
        </interface>
    </interfaces>
    <lu  xmlns="urn:example:clixon"><k>a</k></lu>
    <lu  xmlns="urn:example:clixon"><k>b</k></lu>
    <llu  xmlns="urn:example:clixon">a</llu>
    <llu  xmlns="urn:example:clixon">b</llu>
</${DATASTORE_TOP}>"
EOF

# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend  -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

## Test client and server capabilities

new "4.5.2 NETCONF client does not support private candidate. Verify that connection not possible."
expecteof "$clixon_netconf -ef $cfg " 255 "$DEFAULTHELLO" ""

PRIVCANDHELLO="<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTONLY><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:base:1.1</capability><capability>urn:ietf:params:netconf:capability:private-candidate:1.0</capability></capabilities></hello>]]>]]>"

new "4.5.1 NETCONF server advertise private candidate capability according to runtime (startup) configuration"
expecteof "$clixon_netconf -f $cfg" 0 "$PRIVCANDHELLO" \
"<capability>urn:ietf:params:netconf:capability:private-candidate:1.0?supported-resolution-modes=revert-on-conflict</capability>" "^$"

new "4.8.1.1.1 <resolution-mode> parameter revert-on-conflict accepted"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><update xmlns=\"urn:ietf:params:xml:ns:netconf:private-candidate:1.0\"><resolution-mode>revert-on-conflict</resolution-mode></update></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "# 4.8.1.1.1 <resolution-mode> parameter revert-on-conflict is optional"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><update xmlns=\"urn:ietf:params:xml:ns:netconf:private-candidate:1.0\"/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "4.8.1.1 <update> operation by client not ok, prefer-candidate conflict resolution."
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><update xmlns=\"urn:ietf:params:xml:ns:netconf:private-candidate:1.0\"><resolution-mode>prefer-candidate</resolution-mode></update></rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" message-id=\"42\"><rpc-error><error-type>application</error-type><error-tag>operation-not-supported</error-tag><error-severity>error</error-severity><error-message>Resolution mode not supported</error-message></rpc-error></rpc-reply>"

new "4.8.1.1 <update> operation by client not ok, prefer-running conflict resolution"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><update xmlns=\"urn:ietf:params:xml:ns:netconf:private-candidate:1.0\"><resolution-mode>prefer-running</resolution-mode></update></rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" message-id=\"42\"><rpc-error><error-type>application</error-type><error-tag>operation-not-supported</error-tag><error-severity>error</error-severity><error-message>Resolution mode not supported</error-message></rpc-error></rpc-reply>"

new "Spawn expect script to simulate two NETCONF sessions"
# -d to debug matching info
sudo expect - "$clixon_netconf" "$cfg" $(whoami) <<'EOF'
# Use of expect to start two NETCONF sessions
log_user 0
set timeout 2
set clixon_netconf [lindex $argv 0]
set CFG [lindex $argv 1]
set USER [lindex $argv 2]

puts "Spawn first NETCONF session"
global session_1
spawn {*}sudo -u $USER clixon_netconf -f $CFG -- -e
set session_1 $spawn_id

puts "Wait for hello message from server"
expect {
    -i $session_1
    -re "revert-on-conflict.*]]>]]>" {}
    timeout { puts "timeout: No hello from server session 1"; exit 2 }
    eof { puts "1 eof: No hello from server session 1"; exit 3 }
}
set hello_msg "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:capability:private-candidate:1.0</capability></capabilities></hello>]]>]]>\r"
puts "Send hello message"
send -i session_1 $hello_msg

puts "Spawn second NETCONF session"
global session_2
spawn {*}sudo -u $USER clixon_netconf -f $CFG -- -e
set session_2 $spawn_id

puts "Wait for hello message from server"
expect {
    -i $session_2
    -re "revert-on-conflict.*]]>]]>" {}
    timeout { puts "timeout: No hello from server session 2"; exit 2 }
    eof { puts "1 eof: No hello from server session 2"; exit 3 }
}

puts "Send hello message"
send -i session_2 $hello_msg
sleep 1

# NETCONF rpc operation
proc rpc {session operation reply} {
	send -i $session "<rpc message-id=\"42\" xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\">$operation</rpc>]]>]]>\r"
	expect {
	    -i $session
	    -re "$reply.*</rpc-reply>.*]]>]]>" {}
	    timeout { puts "timeout: $operation $reply"; exit 2 }
	    eof { puts "eof": $operation $reply"; exit 3 }
	}
}

# Verify test data
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "London.*Tokyo"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "London.*Tokyo"

puts "4.7.3.3  Revert-on-conflict example"
# Session 1 edits the configuration
rpc $session_1 	"<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Link to San Francisco</description></interface></interfaces></config></edit-config>" "ok/"

# Session 2 edits the configuration
rpc $session_2 "<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name operation=\"delete\">intf_one</name></interface><interface><name>intf_two</name><description>Link to Paris</description></interface></interfaces></config></edit-config>" "ok/"

# TODO A conflict is detected, the update fails with an <rpc-error> and no merges/overwrite operations happen.
#rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:netconf:private-candidate:1.0\"><resolution-mode>revert-on-conflict</resolution-mode></update>" "rpc-error"
# TODO Verify private candidates
#rpc $session_1 "<get-config><source><candidate/></source></get-config>" "Francisco.*Tokyo"
#rpc $session_2 "<get-config><source><candidate/></source></get-config>" "Paris"

## 4.7.1 No conflicts between sessions

# Conflict est sequence: update session 1, update and commit session 2, update session 1
proc conflict { content_1 content_2 update_reply} {
	global session_1
	global session_2
	#puts "conflict $content_1  $content_2 $update_reply"
	rpc $session_1 "<discard-changes/>" "<ok/>"
	rpc $session_2 "<discard-changes/>" "<ok/>"
	rpc $session_1 "<edit-config><target><candidate/></target><config>$content_1</config></edit-config>" "ok/"
	rpc $session_2 "<edit-config><target><candidate/></target><config>$content_2</config></edit-config>" "<ok/>"
	rpc $session_2 "<commit/>" "<ok/>"
	rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:netconf:private-candidate:1.0\"/>" $update_reply
}
puts "4.8.1.1 <update> operation by client without conflict: There is a change of any value"
conflict "<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Link to San Francisco</description></interface></interfaces>" "<table xmlns=\"urn:example:clixon\"><parameter><name>foo</name><value operation=\"replace\">[info cmdcount]</value></parameter></table>" "ok/"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of any list entry"
conflict "<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name operation=\"delete\">intf_one</name></interface></interfaces>" "<table xmlns=\"urn:example:clixon\"><parameter><name>foo</name><value operation=\"replace\">[info cmdcount]</value></parameter></table>" "ok/"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of a presence container"
conflict "<table xmlns=\"urn:example:clixon\" operation=\"delete\"></table>" "<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Link to Gothenburg</description></interface></interfaces>" "ok/"

puts "4.8.1.1 <update> operation by client without conflict: here is a change of any component member of a leaf-list"
conflict "<ll xmlns=\"urn:example:clixon\">foo</ll>" "<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Link to Stockholm</description></interface></interfaces>" "ok/"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of a leaf"
conflict "<l xmlns=\"urn:example:clixon\">foo</l>" "<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Link to Visby</description></interface></interfaces>" "ok/"

puts "4.8.1.1 <update> operation by client without conflict: There is a change to the order of any list items in a list configured as ordered-by user"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<lu xmlns=\"urn:example:clixon\"><k>a</k></lu><lu xmlns=\"urn:example:clixon\"><k>b</k></lu>"
conflict "<lu xmlns=\"urn:example:clixon\" operation=\"insert\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"first\"><k>b</k></lu>" "<l xmlns=\"urn:example:clixon\">bar</l>" "ok/"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<lu xmlns=\"urn:example:clixon\"><k>b</k></lu><lu xmlns=\"urn:example:clixon\"><k>a</k></lu>"

puts "4.8.1.1 <update> operation by client without conflict: There is a change to the order of any items in a leaf-list configured as ordered-by user"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<llu xmlns=\"urn:example:clixon\">a</llu><llu xmlns=\"urn:example:clixon\">b</llu>"
conflict "<llu xmlns=\"urn:example:clixon\" operation=\"replace\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"first\">b</llu>" "<l xmlns=\"urn:example:clixon\">bar</l>" "ok/"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<llu xmlns=\"urn:example:clixon\">b</llu><llu xmlns=\"urn:example:clixon\">a</llu>"

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
