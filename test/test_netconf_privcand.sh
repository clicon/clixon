#!/usr/bin/env bash
### Netconf private candidate functionality
### See NETCONF and RESTCONF Private Candidate Datastores draft-ietf-netconf-privcand-07

## Test cases implemented
# 4.5.1 NETCONF server advertise private candidate capability according to runtime (startup) configuration
# 4.5.2 NETCONF client does not support private candidate. Verify that connection not possible.
# 4.5.2 NETCONF client supports private candidate. Verify that each client uses its own private candidate.
# 4.5.3 RESTCONF client always operates on private candidate
# 4.7.5 Support revert-on-conflict resolution mode capability.
# 4.8.1.1 <update> operation by client without conflict: There is a change of any value
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict. There is a change of any value
# 4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of any list entry
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of any list entry
# 4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of a presence container
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of a presence container
# 4.8.1.1 <update> operation by client without conflict: here is a change of any component member of a leaf-list
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of any component member of a leaf-list
# 4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of a leaf
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of a leaf
# 4.8.1.1 <update> operation by client without conflict: There is a change to the order of any list items in a list configured as "ordered-by user"
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change to the order of any list items in a list configured as "ordered-by user"
# 4.8.1.1 <update> operation by client without conflict: There is a change to the order of any items in a leaf-list configured as "ordered-by user"
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change to the order of any items in a leaf-list configured as "ordered-by user"
# (4.8.1.1 <update> operation by client without conflict: There is a change to any YANG metadata associated with the node (Note. metadata cannot be changed in Clixon.)
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change to any YANG metadata associated with the node (Note. metadata cannot be changed in Clixon.)
# 4.8.1.1.1 <resolution-mode> parameter> revert-on-conflict accepted
# 4.8.1.1.1 <resolution-mode> parameter revert-on-conflict is optional
# 4.8.1.1 <update> operation by client not ok, prefer-candidate conflict resolution.
# 4.8.1.1 <update> operation by client not ok, prefer-running conflict resolution
# 4.8.2.1 <commit> implicit update ok
# 4.8.2.1 <commit> implicit update failed with when revert-on-conflict resolution
# 4.8.2.1.1 <confirned/> commit ok/canceled/timeout
# 4.8.1.1 <update> operation implicit by server not ok, prefer-candidate conflict resolution (NOTE resolution mode not supported)
# 4.8.1.1 <update> operation implicit by server not ok, prefer-running conflict resolution (NOTE resolution mode not supported)
# 4.8.2.2 <get-config> creates private candidate
# 4.8.2.2 <get-config> operates on private candidate
# 4.8.2.3 <edit-config> creates private candidate
# 4.8.2.3 <edit-config> operates on private candidate
# 4.8.2.4 <copy-config> creates private candidate
# 4.8.2.4 <copy-config> operates on private candidate
# 4.8.2.5 <get-data> creates private candidate (Operation <get-data> not supported by clixon)
# 4.8.2.5 <get-data> operates on private candidate (Operation <get-data> not supported by clixon)
# 4.8.2.6 <edit-data> creates private candidate (Operation <edit-data> not supported by clixon)
# 4.8.2.6 <edit-data> operates on private candidate (Operation <edit-data> not supported by clixon)
# 4.8.2.7 <compare> not supported !
# 4.8.2.8 <lock> operates on private candidate
# 4.8.2.9 <unlock> operates on private candidate
# 4.8.2.10 <delete-config> operates on private candidate (NOTE. candidate as target is not defined in RFC)
# 4.8.2.11 <discard-changes> operates on private candidate
# 4.8.2.12 <get> no private candidate
# 4.8.2.13 <cancel-commit>

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example
echo $dir
cfg=$dir/conf_yang.xml
dbdir=$dir/db
fyang=$dir/clixon-example.yang
test -d $dbdir || mkdir -p $dbdir

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)
if [ $? -ne 0 ]; then
    err1 "Error when generating certs"
fi

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-netconf:confirmed-commit</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_FEATURE>ietf-netconf-private-candidate:private-candidate</CLICON_FEATURE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_NETCONF_MESSAGE_ID_OPTIONAL>false</CLICON_NETCONF_MESSAGE_ID_OPTIONAL>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dbdir</CLICON_XMLDB_DIR>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
  <CLICON_CLI_OUTPUT_FORMAT>xml</CLICON_CLI_OUTPUT_FORMAT>
  <CLICON_XMLDB_PRIVATE_CANDIDATE>true</CLICON_XMLDB_PRIVATE_CANDIDATE>
  $RESTCONFIG
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
    container src-ip {
        choice ip-choice {
            case host {
                leaf host {
                 type string;
                }
            }
            case source-any {
                leaf any {
                    type empty;
                }
            }
        }
    }
}
EOF

new "test params: -f $cfg -s startup"
cat <<EOF > $dbdir/startup_db
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
    <table xmlns="urn:example:clixon"><parameter><name>foo</name><value>0</value></parameter></table>
    <lu  xmlns="urn:example:clixon"><k>a</k></lu>
    <lu  xmlns="urn:example:clixon"><k>b</k></lu>
    <llu  xmlns="urn:example:clixon">a</llu>
    <llu  xmlns="urn:example:clixon">b</llu>
    <ll  xmlns="urn:example:clixon">a</ll>
    <l xmlns="urn:example:clixon">0</l>
</${DATASTORE_TOP}>"
EOF

# add database files to mimic a previous uncontrolled termination of clixon
echo "crash" > $dir/db/candidate_db            # shared
echo "crash" > $dir/db/candidate.12345_db      # privcand
echo "crash" > $dir/db/candidate-orig.12345_db # privcand orig
test -d $dir/db/candidate.6789.d || mkdir $dir/db/candidate.6789.d
echo "crash" > $dir/db/candidate.6789.d/0.xml  # multi
test -d $dir/db/candidate-orig.6789.d || mkdir $dir/db/candidate-orig.6789.d
echo "crash" > $dir/db/candidate-orig.6789.d/0.xml

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

new "Issue 631: Private candidate datastores are not deleted at start"
if  ls $dir/db/candidate* >/dev/null 2>&1; then
    ls $dir/db/candidate*
    err1
fi

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

## Test client and server capabilities

new "4.5.2 NETCONF client does not support private candidate. Verify that connection not possible."
expecteof "$clixon_netconf -ef $cfg " 255 "$DEFAULTHELLO" ""

PRIVCANDHELLO="<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTONLY><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:base:1.1</capability><capability>urn:ietf:params:netconf:capability:private-candidate:1.0</capability></capabilities></hello>]]>]]>"

new "4.5.1 NETCONF server advertise private candidate capability according to runtime (startup) configuration"
expecteof "$clixon_netconf -f $cfg" 0 "$PRIVCANDHELLO" \
"<capability>urn:ietf:params:netconf:capability:private-candidate:1.0?supported-resolution-modes=revert-on-conflict</capability>" "^$"

new "4.8.1.1.1 <resolution-mode> parameter revert-on-conflict accepted"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"><resolution-mode>revert-on-conflict</resolution-mode></update></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "4.8.1.1.1 <resolution-mode> parameter revert-on-conflict is optional"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "4.8.1.1 <update> operation by client not ok, prefer-candidate conflict resolution."
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"><resolution-mode>prefer-candidate</resolution-mode></update></rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" message-id=\"42\"><rpc-error><error-type>application</error-type><error-tag>operation-not-supported</error-tag><error-severity>error</error-severity><error-message>Resolution mode not supported</error-message></rpc-error></rpc-reply>"

new "4.8.1.1 <update> operation by client not ok, prefer-running conflict resolution"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$PRIVCANDHELLO" "<rpc $DEFAULTNS><update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"><resolution-mode>prefer-running</resolution-mode></update></rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" message-id=\"42\"><rpc-error><error-type>application</error-type><error-tag>operation-not-supported</error-tag><error-severity>error</error-severity><error-message>Resolution mode not supported</error-message></rpc-error></rpc-reply>"

new "4.5.3 RESTCONF  Retrieve the Server Capability Information json"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/ietf-netconf-monitoring:netconf-state/capabilities/capability)" 0 "HTTP/$HVER 200" "Content-Type: application/yang-data+json" \
'Cache-Control: no-cache' \
'"urn:ietf:params:netconf:capability:private-candidate:1.0?supported-resolution-modes=revert-on-conflict"'

new "4.5.3 RESTCONF Retrieve the Server Capability Information xml"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/ietf-netconf-monitoring:netconf-state/capabilities/capability)" 0 "HTTP/$HVER 200" "Content-Type: application/yang-data+xml" \
'Cache-Control: no-cache' \
'<capability xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring">urn:ietf:params:netconf:capability:private-candidate:1.0?supported-resolution-modes=revert-on-conflict</capability>'

new "Spawn expect script to simulate two NETCONF sessions"
# -d to debug matching info
# -f- means read commands from stdin
sudo expect -f- "$clixon_netconf" "$cfg" "$RCPROTO" $(whoami) <<'EOF'
# Use of expect to start two NETCONF sessions
log_user 0
set timeout 2
set clixon_netconf [lindex $argv 0]
set CFG [lindex $argv 1]
set RCPROTO [lindex $argv 2]
set USER [lindex $argv 3]

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

# NETCONF rpc operation
proc rpc {session operation { reply "<ok/>"}} {
    set id [info cmdcount]
    #puts "$session <rpc message-id=\"$id\" $operation"
	send -i $session "<rpc message-id=\"$id\" xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\">$operation</rpc>]]>]]>\r"
	expect {
	    -i $session
	    -re ".*message-id=\"$id\".*$reply.*</rpc-reply>.*]]>]]>" {}
	    timeout { puts "\n\nERROR: Expected reply: \"$reply\" on operation: \"$operation\""; exit 2 }
	    eof { puts "\n\neof: $operation $reply"; exit 3 }
	}
}

# Dump both private candidates and running configuration
proc dump {} {
    log_user 1
    global session_1
    global session_2
    puts "\nprivate candidate session 1:"
    rpc $session_1 "<get-config><source><candidate/></source></get-config>" "data"
    puts "\n\nprivate candidate session 2:"
    rpc $session_2 "<get-config><source><candidate/></source></get-config>" "data"
    puts "\n\nrunning:"
    rpc $session_1 "<get-config><source><running/></source></get-config>" "data"
    log_user 0
}

## Start of 4.7.3.3  Revert-on-conflict example

puts "4.7.3.3 Session 1 edits the configuration"
rpc $session_1 	"<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Link to San Francisco</description></interface></interfaces></config></edit-config>"

puts "4.7.3.3 Session 2 edits the configuration"
rpc $session_2 "<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name >intf_one</name></interface><interface><name>intf_two</name><description>Link to Paris</description></interface></interfaces></config></edit-config>"

puts "4.5.2 NETCONF client supports private candidate. Verify that each client uses its own private candidate"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "Francisco.*Tokyo"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "Paris"

puts "4.7.3.3 Session 2 commits the change"
rpc $session_2 "<commit/>"

puts "4.7.3.3 Session 1 updates its configuration and fails"
# A conflict is detected, the update fails with an <rpc-error> and no merges/overwrite operations happen.
rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"><resolution-mode>revert-on-conflict</resolution-mode></update>" "Conflict occured: Cannot change node value, node is removed"

puts "4.7.3.3 Session 1 discards its changes"
puts "4.8.2.11 <discard-changes> operates on private candidate"
rpc $session_1 "<discard-changes/>"

puts "4.7.3.3 Session 1 updates its configuraion successfully"
rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"/>"

# Conflict est sequence: reset session 1, edit and commit session 2, edit and update session 1
proc conflict { content_1 content_2 update_reply} {
	global session_1
	global session_2
	#puts "\nconflict $update_reply\n content 1: $content_1  \n content 2: $content_2 \n"
    # Session 1 edits configuration
	rpc $session_1 "<edit-config><target><candidate/></target><config>$content_1</config></edit-config>" 
	# Session 2 edits and commits configuration
	rpc $session_2 "<edit-config><target><candidate/></target><config>$content_2</config></edit-config>"
    rpc $session_2 "<commit/>"
    # Session 1 updates its configuration
    rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"/>" $update_reply
    # Reset session 1 after conflict
    rpc $session_1 "<discard-changes/>"
    rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"/>"
}

puts "4.8.1.1 <update> operation by client without conflict: There is a change of any value"
conflict \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_two</name><description>Link to San Francisco</description></interface></interfaces>" \
"<table xmlns=\"urn:example:clixon\"><parameter><name>foo</name><value>[info cmdcount]</value></parameter></table>"  \
"ok/"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict. There is a change of any value"
conflict \
"<table xmlns=\"urn:example:clixon\"><parameter><name>foo</name><value>[info cmdcount]</value></parameter></table>" \
"<table xmlns=\"urn:example:clixon\"><parameter><name>foo</name><value>[info cmdcount]</value></parameter></table>"  \
"Conflict occured: Cannot change node value, it is already changed"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of any list entry"
conflict \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface xmlns:ex=\"urn:example:clixon\"><name>intf_three</name><description>New interface</description><type>ex:eth</type></interface></interfaces>" \
"<table xmlns=\"urn:example:clixon\"><parameter><name>foo</name><value >[info cmdcount]</value></parameter></table>" \
"ok/"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of any list entry"
conflict \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface xmlns:ex=\"urn:example:clixon\"><name>intf_three</name><description>New interface 1</description><type>ex:eth</type></interface></interfaces>" \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface xmlns:ex=\"urn:example:clixon\"><name>intf_three</name><description>New interface 2</description><type>ex:eth</type></interface></interfaces>" \
"Conflict occured: Cannot add node, it is already added"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of a presence container"
conflict \
"<table xmlns=\"urn:example:clixon\"  xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\"/>" \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_two</name><description>Link to Gothenburg</description></interface></interfaces>" \
"ok/"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of a presence container"
conflict \
"<table xmlns=\"urn:example:clixon\"  xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\"/>" \
"<table xmlns=\"urn:example:clixon\"><parameter><name>foo</name><value >[info cmdcount]</value></parameter></table>" \
"Cannot remove node, node value has changed"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of a leaf"
conflict "<l xmlns=\"urn:example:clixon\">foo</l>" \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_two</name><description>Link to Visby</description></interface></interfaces>" \
"ok/"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of a leaf"
conflict "<l xmlns=\"urn:example:clixon\">a</l>" \
"<l xmlns=\"urn:example:clixon\">b</l>" \
"Cannot change node value, it is already changed"

puts "4.8.1.1 <update> operation by client without conflict: There is a change to the order of any list items in a list configured as ordered-by user"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<lu xmlns=\"urn:example:clixon\"><k>a</k></lu><lu xmlns=\"urn:example:clixon\"><k>b</k></lu>"
conflict "<lu xmlns=\"urn:example:clixon\" operation=\"insert\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"first\"><k>b</k></lu>" \
"<l xmlns=\"urn:example:clixon\">bar</l>" \
"ok/"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<lu xmlns=\"urn:example:clixon\"><k>b</k></lu><lu xmlns=\"urn:example:clixon\"><k>a</k></lu>"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change to the order of any list items in a list configured as ordered-by user"
conflict "<lu xmlns=\"urn:example:clixon\" operation=\"insert\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"first\"><k>a</k></lu>" \
"<lu xmlns=\"urn:example:clixon\" operation=\"insert\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"last\"><k>b</k></lu>" \
"Conflict occured: Cannot remove node, it is already removed"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<lu xmlns=\"urn:example:clixon\"><k>b</k></lu><lu xmlns=\"urn:example:clixon\"><k>a</k></lu>"

puts "4.8.1.1 <update> operation by client without conflict: There is a change to the order of any items in a leaf-list configured as ordered-by user"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<llu xmlns=\"urn:example:clixon\">a</llu><llu xmlns=\"urn:example:clixon\">b</llu>"
conflict "<llu xmlns=\"urn:example:clixon\" operation=\"replace\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"first\">b</llu>" \
"<l xmlns=\"urn:example:clixon\">bar</l>" \
"ok/"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<llu xmlns=\"urn:example:clixon\">b</llu><llu xmlns=\"urn:example:clixon\">a</llu>"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change to the order of any items in a leaf-list configured as ordered-by user"
conflict "<llu xmlns=\"urn:example:clixon\" operation=\"replace\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"first\">a</llu>" \
"<llu xmlns=\"urn:example:clixon\" operation=\"replace\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"last\">b</llu>" \
"Cannot remove node, it is already removed"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<llu xmlns=\"urn:example:clixon\">b</llu><llu xmlns=\"urn:example:clixon\">a</llu>"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of any component member of a leaf-list"
conflict "<ll xmlns=\"urn:example:clixon\">foo</ll>" \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_two</name><description>Link to Stockholm</description></interface></interfaces>" \
"ok/"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of any component member of a leaf-list"
conflict "<ll xmlns=\"urn:example:clixon\">b</ll>" \
"<ll xmlns=\"urn:example:clixon\">c</ll>" \
"Conflict occured: Cannot add leaf-list node, another leaf-list node is added"

rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">one</l></config></edit-config>"
rpc $session_2 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">two</l></config></edit-config>"
puts "4.8.2.1 <commit> implicit update ok"
rpc $session_1 "<commit/>"
puts "4.8.2.1 <commit> implicit update failed with when revert-on-conflict resolution"
rpc $session_2 "<update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"/>" "rpc-error"
rpc $session_2 "<commit/>" "rpc-error"

puts "4.8.2.2 <get-config> creates private candidate"
# session_1 has no private candidate after previous commit, running holds l="one", session_2 private candidate holds l="two"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">one</l>"
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">three</l></config></edit-config>"
rpc $session_1 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">one</l>"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">three</l>"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">two</l>"
rpc $session_1 "<discard-changes/>"

puts "4.8.2.2 <get-config> operates on private candidate"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">one</l>"
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">four</l></config></edit-config>"
rpc $session_1 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">one</l>"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">four</l>"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">two</l>"
rpc $session_1 "<commit/>"

puts "4.8.2.3 <edit-config> creates private candidate"
# session_1 has no private candidate after previous commit, running holds l="four", session_2 private candidate holds l="two"
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">five</l></config></edit-config>"
rpc $session_1 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">four</l>"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">five</l>"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">two</l>"
rpc $session_1 "<discard-changes/>"

puts "4.8.2.3 <edit-config> operates on private candidate"
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">six</l></config></edit-config>"
rpc $session_1 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">four</l>"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">six</l>"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">two</l>"
rpc $session_1 "<commit/>"

puts "4.8.2.4 <copy-config> creates private candidate"
rpc $session_1 "<copy-config><target><candidate/></target><source><startup/></source></copy-config>"
rpc $session_1 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">six</l>"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">0</l>"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">two</l>"
rpc $session_1 "<discard-changes/>"
rpc $session_1 "<copy-config><target><candidate/></target><source><running/></source></copy-config>"
rpc $session_1 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">six</l>"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">six</l>"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">two</l>"
rpc $session_1 "<commit/>"

puts "4.8.2.4 <copy-config> operates on private candidate"
rpc $session_1 "<copy-config><target><candidate/></target><source><running/></source></copy-config>"
rpc $session_1 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">six</l>"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">six</l>"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "<l xmlns=\"urn:example:clixon\">two</l>"
rpc $session_1 "<commit/>"

# Reset private candidates
rpc $session_1 "<discard-changes/>"
rpc $session_2 "<discard-changes/>"

puts "4.8.2.8 <lock> operates on private candidate"
rpc $session_1 "<lock><target><candidate/></target></lock>"
rpc $session_2 "<lock><target><candidate/></target></lock>"
rpc $session_1 "<lock><target><candidate/></target></lock>" "error"

puts "4.8.2.9 <unlock> operates on private candidate"
rpc $session_1 "<unlock><target><candidate/></target></unlock>"
rpc $session_2 "<unlock><target><candidate/></target></unlock>"
rpc $session_2 "<unlock><target><candidate/></target></unlock>" "error"

puts "Smoke test of lock handling for running"
rpc $session_1 "<lock><target><running/></target></lock>"
rpc $session_2 "<lock><target><running/></target></lock>" "error"
rpc $session_1 "<unlock><target><running/></target></unlock>"

puts "4.8.2.12 <get> no private candidate"
# the rpc-reply of the get operation will be very long
match_max 100000 
rpc $session_2 "<get/>" "<l xmlns=\"urn:example:clixon\">six</l>"

puts "4.5.3 RESTCONF request updates object"
set json "{\"clixon-example:l\":\"restconf 1\"}"
set rsp [exec curl -Ssik -X PUT -H "Accept:application/yang-data+json" -H "Content-Type:application/yang-data+json" -d $json $RCPROTO://localhost/restconf/data/clixon-example:l ]
if {[string match {*204*} $rsp] == 0} {
    puts "Restconf response: $rsp"
    exit 4
}

puts "4.5.3 NETCONF verifies RESTCONF update in running"
rpc $session_1 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">restconf 1</l>"

puts "4.5.3 NETCONF update operation ok"
rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"/>"
 
puts "4.5.3 NETCONF updates object in private candidate"
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">netconf</l></config></edit-config>"
 
 puts "4.5.3 RESTCONF request updates object"
 set json "{\"clixon-example:l\":\"restconf 2\"}"
set rsp [exec curl -Ssik -X PUT -H "Accept:application/yang-data+json" -H "Content-Type:application/yang-data+json" -d $json $RCPROTO://localhost/restconf/data/clixon-example:l ]
if {[string match {*204*} $rsp] == 0} {
    puts "Restconf response: $rsp"
    exit 4
}

puts "4.5.3 NETCONF verifies RESTCONF update in running"
rpc $session_1 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">restconf 2</l>"

puts "4.5.3 NETCONF update operation fails"
rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"/>" "rpc-error"
rpc $session_1 "<discard-changes/>"
rpc $session_1 "<commit/>"

puts "Adhoc test 1: should fail, interface intf_one does not exist and mandatory type not included"
rpc $session_2 	"<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Adhoc</description></interface></interfaces></config></edit-config>"
rpc $session_2 "<commit/>" "rpc-error"

puts "Adhoc test 2: interface intf_one without description"
rpc $session_2 	"<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface  xmlns:ex=\"urn:example:clixon\"><name>intf_one</name><type>ex:eth</type></interface></interfaces></config></edit-config>"
rpc $session_2 "<commit/>"

puts "Adhoc test 3: interface intf_one description updated from both sessions"
rpc $session_1 	"<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Session 1</description></interface></interfaces></config></edit-config>"
rpc $session_2 	"<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Session 2</description></interface></interfaces></config></edit-config>"
puts "session 1 commit"
rpc $session_1 "<commit/>"
puts "session 2 commit"
rpc $session_2 "<commit/>" "rpc-error"

# reset session
rpc $session_1 "<discard-changes/>"
rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"/>"
rpc $session_2 "<discard-changes/>"
rpc $session_2 "<update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"/>"

puts "4.8.2.1.1 <confirmed/> commit ok"
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">commit</l></config></edit-config>"
rpc $session_1 "<commit><confirmed/><confirm-timeout>1</confirm-timeout></commit>"
rpc $session_1 "<commit/>"
sleep 2
rpc $session_2 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">commit</l>"

puts "4.8.2.1.1 <confirmed/> commit cancel"
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">commit-cancel</l></config></edit-config>"
rpc $session_1 "<commit><confirmed/><confirm-timeout>1</confirm-timeout></commit>"
rpc $session_2 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">commit-cancel</l>"
puts "4.8.2.13 <cancel-commit>"
rpc $session_1 "<cancel-commit/>"
sleep 2
rpc $session_2 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">commit</l>"

puts "4.8.2.1.1 <confirmed/> commit timeout"
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">commit-timeout</l></config></edit-config>"
rpc $session_1 "<commit><confirmed/><confirm-timeout>1</confirm-timeout></commit>"
rpc $session_2 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">commit-timeout</l>"
sleep 2
rpc $session_2 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">commit</l>"

puts "4.8.2.1.1 <confirmed/> commit persist"
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">commit-persist</l></config></edit-config>"
rpc $session_1 "<commit><confirmed/><confirm-timeout>1</confirm-timeout><persist>id</persist></commit>"
rpc $session_2 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">commit-persist</l>"
rpc $session_2 "<commit><confirmed/><persist-id>id</persist-id></commit>"
sleep 2
rpc $session_2 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">commit-persist</l>"

rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">netconf-ok</l></config></edit-config>"
rpc $session_1 "<commit/>"

puts "Spawn CLI session"
spawn {*}sudo -u $USER clixon_cli -f $CFG
set session_cli_1 $spawn_id

puts "Spawn second CLI session"
spawn {*}sudo -u $USER clixon_cli -f $CFG
set session_cli_2 $spawn_id

# cli command function
proc cli { session command { reply "" }} {
    send -i $session "$command\n"
    expect {
        -i $session
        -re "$command.*$reply.*\@.*\/> " {puts -nonewline "$session: $expect_out(buffer)"; return $expect_out(buffer)}
	    timeout { puts "\n\ntimeout"; exit 2 }
	    eof { puts "\n\neof"; exit 3 }
    }
}
# wait for prompt
cli $session_cli_1 ""
cli $session_cli_2 ""

# create private netconf candidate
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">netconf-conflict</l></config></edit-config>"

cli $session_cli_1 "set l \"cli-ok\""
cli $session_cli_1 "commit"
rpc $session_1 "<get-config><source><running/></source></get-config>" "<l xmlns=\"urn:example:clixon\">cli-ok</l>"

rpc $session_1 "<commit/>" "Conflict occured"
rpc $session_1 "<discard-changes/>"
rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-private-candidate\"/>"

cli $session_cli_1 "set l \"cli-conflict\""
rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">netconf-ok</l></config></edit-config>"
rpc $session_1 "<commit/>"
cli $session_cli_1 "commit" "Conflict occured"

cli $session_cli_1 "discard"
cli $session_cli_1 "update"
cli $session_cli_1 "set l \"cli-retry\""
cli $session_cli_1 "commit"

# Controller Issue: show compare private candidate #233
cli $session_cli_1 "set l \"TEST9\""
cli $session_cli_1 "commit"
cli $session_cli_2 "show compare"
cli $session_cli_1 "set l \"TEST10\""
cli $session_cli_1 "commit"
if {[string match *TEST* [cli $session_cli_2 "show compare"]]} {
    puts "Controller Issue #233: show compare private candidate"
    exit 4
}

# Issue #644 test case
cli $session_cli_1 ""
cli $session_cli_1 "set src-ip any"
cli $session_cli_1 "commit"
cli $session_cli_1 "set src-ip host \"1.2.3.4\""
if {[string match *fail* [cli $session_cli_1 "commit"]]} {
    puts "Issue #644: Private candidate commit fails when changing YANG choice case"
    exit 5
}

puts "\nClose sessions"
close $session_cli_1
close $session_cli_2
close $session_1
close $session_2
EOF

if [ $? -ne 0 ]; then
    err1 "Failed: test private candidate using expect"
fi

new "Issue 631: Private candidate datastores are not deleted at end"
if  ls $dir/db/candidate* >/dev/null 2>&1; then
    ls $dir/db/candidate*
    err1
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
