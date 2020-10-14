#!/usr/bin/env bash
# Backend and cli basic functionality
# Start backend server
# Add an ethernet interface and an address
# Show configuration
# Validate without a mandatory type
# Set the mandatory type
# Commit

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fspec=$dir/automode.cli
fin=$dir/in
fstate=$dir/state.xml

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
</clixon-config>
EOF

cat <<EOF > $fspec
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
edit @datamodel, cli_auto_edit("datamodel", "candidate");
up, cli_auto_up("datamodel", "candidate");
top, cli_auto_top("datamodel", "candidate");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") @datamodel, cli_auto_del();

validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "xml", false, false);{
	    xml("Show configuration as XML"), cli_auto_show("datamodel", "candidate", "xml", false, false);
	    cli("Show configuration as CLI commands"), cli_auto_show("datamodel", "candidate", "cli", false, false, "set ");
	    netconf("Show configuration as netconf edit-config operation"), cli_auto_show("datamodel", "candidate", "netconf", false, false);
	    text("Show configuration as text"), cli_auto_show("datamodel", "candidate", "text", false, false);
	    json("Show configuration as JSON"), cli_auto_show("datamodel", "candidate", "json", false, false);
    }
    state("Show configuration and state"), cli_auto_show("datamodel", "running", "xml", false, true);
}
EOF

cat <<EOF > $dir/startup_db
<config>
  <table xmlns="urn:example:clixon">
    <parameter>
      <name>a</name>
      <value>42</value>
    </parameter>
  </table>
</config>
EOF

# Add inline state
cat <<EOF > $fstate
  <table xmlns="urn:example:clixon">
    <parameter>
      <name>a</name>
      <stat>99</stat>
    </parameter>
  </table>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s startup -f $cfg -- -sS $fstate"
    start_backend -s startup -f $cfg -- -sS $fstate

    new "waiting"
    wait_backend
fi

# First go down in structure and show config
new "show top tree"
expectpart "$(echo "show config" | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>$'

cat <<EOF > $fin
up
show config
EOF
new "up show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>$'

cat <<EOF > $fin
edit table
show config
EOF
new "edit table; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table>" "<parameter><name>a</name><value>42</value></parameter>$" --not-- '<table xmlns="urn:example:clixon">'

cat <<EOF > $fin
edit table parameter a
show config
EOF
new "edit table parameter a; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table/parameter=a/>" "<name>a</name><value>42</value>" --not-- '<table xmlns="urn:example:clixon">' "<parameter>"

cat <<EOF > $fin
edit table
edit parameter a
show config
EOF
new "edit table; edit parameter a; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "<name>a</name><value>42</value>" --not-- '<table xmlns="urn:example:clixon">' "<parameter>"

cat <<EOF > $fin
edit table parameter a value 42
show config
EOF
new "edit table parameter a value 42; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 --not-- '<table xmlns="urn:example:clixon">' "<parameter>" "<name>a</name>" "<value>42</value>"

# edit -> top
cat <<EOF > $fin
edit table parameter a value 42
top
show config
EOF
new "edit table parameter a value 42; top; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>$'

cat <<EOF > $fin
edit table parameter a
top
show config
EOF
new "edit table parameter a; top; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>$'

# edit -> up

cat <<EOF > $fin
edit table
up
show config
EOF
new "edit table; up; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>$'

cat <<EOF > $fin
edit table parameter a
up
show config
EOF
new "edit table parameter a; up; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table>" "<parameter><name>a</name><value>42</value></parameter>$" --not-- '<table xmlns="urn:example:clixon">'

cat <<EOF > $fin
edit table parameter a
up
up
show config
EOF
new "edit table parameter a; up up; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>$'

cat <<EOF > $fin
edit table parameter a
up
edit parameter a
show config
EOF
new "edit table parameter a; up; edit parameter a; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table/parameter=a/>" "<name>a</name><value>42</value>" --not-- '<table xmlns="urn:example:clixon">' "<parameter>"

# Create new field b, and remove it
cat <<EOF > $fin
edit table parameter b
show config
EOF
new "edit table parameter b; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table/parameter=b/>" --not-- "<name>a</name><value>42</value>"  '<table xmlns="urn:example:clixon">' "<parameter>"

cat <<EOF > $fin
edit table parameter b
set value 71
up
show config
EOF
new "set value 71"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table>" "<parameter><name>a</name><value>42</value></parameter><parameter><name>b</name><value>71</value></parameter>"

cat <<EOF > $fin
edit table parameter b
delete value 17
show config
EOF
new "delete value 71"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "<name>b</name>" --not-- "<value>71</value>"

cat <<EOF > $fin
edit table
delete parameter b
up
show config
EOF
new "delete parameter b"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>$'

# Back to startup
# show state

cat <<EOF > $fin
edit table
show state
EOF
new "show state"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "<parameter><name>a</name><value>42</value><stat>99</stat></parameter>$"

# Show other formats
cat <<EOF > $fin
edit table
show config json
EOF
new "show config json"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '{"clixon-example:parameter":{"name":"a","value":"42"}}'

cat <<EOF > $fin
edit table
show config text
EOF
new "show config text"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "parameter {" "name a;" "value 42;"

cat <<EOF > $fin
edit table
show config cli
EOF
new "show config cli"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "set parameter a value 42$"

cat <<EOF > $fin
edit table
show config netconf
EOF
new "show config netconf"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><config><parameter><name>a</name><value>42</value></parameter></config></edit-config></rpc>]]>]]>'

endtest

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
