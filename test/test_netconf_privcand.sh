#!/usr/bin/env bash
### Netconf private candidate functionality
### See NETCONF and RESTCONF Private Candidate Datastores draft-ietf-netconf-privcand-07

## Test cases implemented
# 4.5.1 NETCONF server advertise private candidate capability according to runtime (startup) configuration
# 4.5.2 NETCONF client does not support private candidate. Verify that connection not possible.
# 4.5.2 NETCONF client supports private candidate. Verify that each client uses its own private candidate.
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
# (4.8.1.1 <update> operation by client without conflict: There is a change to any YANG metadata associated with the node Note. metadata cannot be changed in Clixon.)
# 4.8.1.1.1 <resolution-mode> parameter> revert-on-conflict accepted
# 4.8.1.1.1 <resolution-mode> parameter revert-on-conflict is optional
# 4.8.1.1 <update> operation by client not ok, prefer-candidate conflict resolution.
# 4.8.1.1 <update> operation by client not ok, prefer-running conflict resolution
# 4.8.2.1 <commit> implicit update ok
# 4.8.2.1 <commit> implicit update failed with when revert-on-conflict resolution
# 4.8.2.8 <lock> operates on private candidate
# 4.8.2.9 <unlock> operates on private candidate

## TODO Test cases to be implemented
# 4.5.3 RESTCONF client always operates on private candidate
# 4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change to any YANG metadata associated with the node
# 4.8.1.1 <update> operation implicit by server not ok, prefer-candidate conflict resolution
# 4.8.1.1 <update> operation implicit by server not ok, prefer-running conflict resolution
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
# 4.8.2.10 <delete-config> operates on private candidate (NOTE. candidate as target is not defined in RFC)
# 4.8.2.7 <compare> not supported !
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
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_NETCONF_MESSAGE_ID_OPTIONAL>false</CLICON_NETCONF_MESSAGE_ID_OPTIONAL>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dbdir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_CANDIDATE_INMEM>false</CLICON_XMLDB_CANDIDATE_INMEM>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
  <CLICON_CLI_OUTPUT_FORMAT>xml</CLICON_CLI_OUTPUT_FORMAT>
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

cat <<EOF > $dir/example_pipe.cli
CLICON_MODE="|example_pipe"; # Must start with |
\| {
   grep("Search for pattern") <arg:string>, pipe_grep_fn("-e", "arg");
   except("Inverted search") <arg:string>, pipe_grep_fn("-v", "arg");
   tail("Output last part") <arg:string>, pipe_tail_fn("-n", "arg");
   count("Line count"), pipe_wc_fn("-l");
   show("Show other format") {
     cli("set Input cli syntax"), pipe_showas_fn("cli", true, "set ");
     xml("XML"), pipe_showas_fn("xml", true);
     json("JSON"), pipe_showas_fn("json");
     text("Text curly braces"), pipe_showas_fn("text");
   }
   save("Save to file") <filename:string>("Local filename"), pipe_save_file("filename");
}
EOF

cat <<EOF > $dir/privcand.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
edit @datamodelmode, cli_auto_edit("basemodel");
up, cli_auto_up("basemodel");
top, cli_auto_top("basemodel");
set @datamodel, cli_auto_set();
set default {
   format("Set default output format") <fmt:string choice:xml|json|text|cli>("CLI output format"), cli_format_set();
}
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") {
      @datamodel, @add:leafref-no-refer, cli_auto_del();
      all("Delete whole candidate configuration"), delete_all("candidate");
}
validate("Validate changes"), cli_validate();
commit("Commit the changes") {
  [persist-id("Specify the 'persist' value of a previous confirmed-commit") <persist-id-val:string show:"string">("The 'persist' value of the persistent confirmed-commit")], cli_commit(); {
    <cancel:string keyword:cancel>("Cancel an ongoing confirmed-commit"), cli_commit();
    <confirmed:string keyword:confirmed>("Require a confirming commit") {
       [persist("Make this confirmed-commit persistent") <persist-val:string show:"string">("The value that must be provided as 'persist-id' in the confirming-commit or cancel-commit")]
       [<timeout:uint32 range[1:4294967295] show:"1..4294967295">("The rollback timeout in seconds")], cli_commit();
    }
  }
}
quit("Quit"), cli_quit();

debug("Debugging parts of the system"){
    cli("Set cli debug")	 <level:int32>("Set debug level (0..n)"), cli_debug_cli();
    backend("Set backend debug") <level:int32>("Set debug level (0..n)"), cli_debug_backend();
    restconf("Set restconf debug") <level:int32>("Set debug level (0..n)"), cli_debug_restconf();
}

shell("System command"), cli_start_shell("bash");{
  <source:rest>("Single shell command"), cli_start_shell("bash");
}
copy("Copy and create a new object") {
    running("Copy from running db")  startup("Copy to startup config"), db_copy("running", "startup");
    interface("Copy interface"){
	(<name:string>|<name:string expand_dbvar("candidate","/ietf-interfaces:interfaces/interface=%s/name")>("name of interface to copy from")) to("Copy to interface") <toname:string>("Name of interface to copy to"), cli_copy_config("candidate","//interface[%s='%s']","urn:ietf:params:xml:ns:yang:ietf-interfaces","name","name","toname");
    }
}
discard("Discard edits (rollback 0)"), discard_changes();

show("Show a particular state of the system"){
    default{
       format("Show default output format"), cli_format_show();
    }
    configuration("Show configuration"), cli_show_auto_mode("candidate", "default", true, false);{
       @|example_pipe, cli_show_auto_mode("candidate", "default", true, false);
       @datamodelshow, cli_show_auto("candidate", "default", true, false);
    }
    2configuration("Show configuration"), cli_show_auto_mode("candidate", "default", true, false, "explicit", "set ");{
       @|example_pipe, cli_show_auto_mode("candidate", "xml", true, false, "explicit");
    }
    debug("Show debug"), cli_debug_show();{
          cli("Show cli debug"), cli_debug_show();
    }
    xpath("Show configuration") <xpath:string>("XPATH expression")
       [<ns:string>("Namespace")], show_conf_xpath("candidate");
    version("Show version"), cli_show_version("candidate", "text", "/");
    options("Show clixon options"), cli_show_options();
    compare("Compare candidate and running databases"), compare_dbs("running", "candidate", "default");{
	    xml("Show comparison in xml"), compare_dbs("running", "candidate", "xml");
		     text("Show comparison in text"), compare_dbs("running", "candidate", "text");
    }

    sessions("Show client sessions"), cli_show_sessions();{
         detail("Show sessions detailed state"), cli_show_sessions("detail");
    }
}
session("Client sessions") {
   kill("Kill client session")
      <session:uint32>("Client session number"), cli_kill_session("session");
}
update("Send private candidate update"), cli_update();
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

new "4.8.1.1.1 <resolution-mode> parameter revert-on-conflict is optional"
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

# NETCONF rpc operation
proc rpc {session operation reply} {
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
rpc $session_1 	"<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Link to San Francisco</description></interface></interfaces></config></edit-config>" "ok/"

puts "4.7.3.3 Session 2 edits the configuration"
rpc $session_2 "<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name >intf_one</name></interface><interface><name>intf_two</name><description>Link to Paris</description></interface></interfaces></config></edit-config>" "ok/"

puts "4.5.2 NETCONF client supports private candidate. Verify that each client uses its own private candidate"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "Francisco.*Tokyo"
rpc $session_2 "<get-config><source><candidate/></source></get-config>" "Paris"

puts "4.7.3.3 Session 2 commits the change"
rpc $session_2 "<commit/>" "ok/"

puts "4.7.3.3 Session 1 updates its configuration and fails"
# A conflict is detected, the update fails with an <rpc-error> and no merges/overwrite operations happen.
rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:netconf:private-candidate:1.0\"><resolution-mode>revert-on-conflict</resolution-mode></update>" "rpc-error"

puts "4.7.3.3 Session 1 discards its changes"
rpc $session_1 "<discard-changes/>" "ok/"

puts "4.7.3.3 Session 1 updates its configuraion successfully"
rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:netconf:private-candidate:1.0\"/>" "ok/"

# Conflict est sequence: reset session 1, edit and commit session 2, edit and update session 1
proc conflict { content_1 content_2 update_reply} {
	global session_1
	global session_2
	#puts "\nconflict $update_reply\n content 1: $content_1  \n content 2: $content_2 \n"
    # Session 1 edits configuration
	rpc $session_1 "<edit-config><target><candidate/></target><config>$content_1</config></edit-config>" "ok/" 
	# Session 2 edits and commits configuration
	rpc $session_2 "<edit-config><target><candidate/></target><config>$content_2</config></edit-config>" "<ok/>"
    rpc $session_2 "<commit/>" "<ok/>"
    # Session 1 updates its configuration
    rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:netconf:private-candidate:1.0\"/>" $update_reply
    # Reset session 1 after conflict
    rpc $session_1 "<discard-changes/>" "ok/"
    rpc $session_1 "<update xmlns=\"urn:ietf:params:xml:ns:netconf:private-candidate:1.0\"/>" "ok/"
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
"rpc-error"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of any list entry"
conflict \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface xmlns:ex=\"urn:example:clixon\"><name>intf_three</name><description>New interface</description><type>ex:eth</type></interface></interfaces>" \
"<table xmlns=\"urn:example:clixon\"><parameter><name>foo</name><value >[info cmdcount]</value></parameter></table>" \
"ok/"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of any list entry"
conflict \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface xmlns:ex=\"urn:example:clixon\"><name>intf_three</name><description>New interface 1</description><type>ex:eth</type></interface></interfaces>" \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface xmlns:ex=\"urn:example:clixon\"><name>intf_three</name><description>New interface 2</description><type>ex:eth</type></interface></interfaces>" \
"rpc-error"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of a presence container"
conflict \
"<table xmlns=\"urn:example:clixon\"  xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\"/>" \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_two</name><description>Link to Gothenburg</description></interface></interfaces>" \
"ok/"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of a presence container"
conflict \
"<table xmlns=\"urn:example:clixon\"  xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\"/>" \
"<table xmlns=\"urn:example:clixon\"><parameter><name>foo</name><value >[info cmdcount]</value></parameter></table>" \
"rpc-error"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of existence (or otherwise) of a leaf"
conflict "<l xmlns=\"urn:example:clixon\">foo</l>" \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_two</name><description>Link to Visby</description></interface></interfaces>" \
"ok/"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of existence (or otherwise) of a leaf"
conflict "<l xmlns=\"urn:example:clixon\">a</l>" \
"<l xmlns=\"urn:example:clixon\">b</l>" \
"rpc-error"

puts "4.8.1.1 <update> operation by client without conflict: There is a change to the order of any list items in a list configured as ordered-by user"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<lu xmlns=\"urn:example:clixon\"><k>a</k></lu><lu xmlns=\"urn:example:clixon\"><k>b</k></lu>"
conflict "<lu xmlns=\"urn:example:clixon\" operation=\"insert\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"first\"><k>b</k></lu>" \
"<l xmlns=\"urn:example:clixon\">bar</l>" \
"ok/"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<lu xmlns=\"urn:example:clixon\"><k>b</k></lu><lu xmlns=\"urn:example:clixon\"><k>a</k></lu>"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change to the order of any list items in a list configured as ordered-by user"
conflict "<lu xmlns=\"urn:example:clixon\" operation=\"insert\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"first\"><k>a</k></lu>" \
"<lu xmlns=\"urn:example:clixon\" operation=\"insert\" xmlns:yang=\"urn:ietf:params:xml:ns:yang:1\" yang\:insert=\"last\"><k>b</k></lu>" \
"rpc-error"
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
"rpc-error"
rpc $session_1 "<get-config><source><candidate/></source></get-config>" "<llu xmlns=\"urn:example:clixon\">b</llu><llu xmlns=\"urn:example:clixon\">a</llu>"

puts "4.8.1.1 <update> operation by client without conflict: There is a change of any component member of a leaf-list"
conflict "<ll xmlns=\"urn:example:clixon\">foo</ll>" \
"<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_two</name><description>Link to Stockholm</description></interface></interfaces>" \
"ok/"

puts "4.8.1.1 <update> operation by client not ok, revert-on-conflict: There is a change of any component member of a leaf-list"
conflict "<ll xmlns=\"urn:example:clixon\">b</ll>" \
"<ll xmlns=\"urn:example:clixon\">c</ll>" \
"rpc-error"

rpc $session_1 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">foo</l></config></edit-config>" "ok/"
rpc $session_2 "<edit-config><target><candidate/></target><config><l xmlns=\"urn:example:clixon\">bar</l></config></edit-config>" "ok/"
puts "4.8.2.1 <commit> implicit update ok"
rpc $session_1 "<commit/>" "ok/"
puts "4.8.2.1 <commit> implicit update failed with when revert-on-conflict resolution"
rpc $session_2 "<commit/>" "rpc-error"

# Reset private candidates
rpc $session_1 "<discard-changes/>" "ok/"
rpc $session_2 "<discard-changes/>" "ok/"

puts "4.8.2.8 <lock> operates on private candidate"
rpc $session_1 "<lock><target><candidate/></target></lock>" "<ok/>"
rpc $session_2 "<lock><target><candidate/></target></lock>" "<ok/>"
rpc $session_1 "<lock><target><candidate/></target></lock>" "error"

puts "4.8.2.9 <unlock> operates on private candidate"
rpc $session_1 "<unlock><target><candidate/></target></unlock>" "<ok/>"
rpc $session_2 "<unlock><target><candidate/></target></unlock>" "<ok/>"
rpc $session_2 "<unlock><target><candidate/></target></unlock>" "error"

puts "Smoke test of lock handling for running"
rpc $session_1 "<lock><target><running/></target></lock>" "<ok/>"
rpc $session_2 "<lock><target><running/></target></lock>" "error"
rpc $session_1 "<unlock><target><running/></target></unlock>" "<ok/>"


puts "Adhoc test 1: should fail, interface intf_one does not exist and mandatory type not included"
rpc $session_2 	"<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Adhoc</description></interface></interfaces></config></edit-config>" "ok/"
rpc $session_2 "<commit/>" "ok/"

puts "Adhoc test 2: second edit of interface intf_one fails"
rpc $session_2 	"<edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>intf_one</name><description>Adhoc 2</description></interface></interfaces></config></edit-config>" "ok/"
rpc $session_2 "<commit/>" "ok/"

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
