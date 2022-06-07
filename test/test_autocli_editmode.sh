#!/usr/bin/env bash
# Auto-cli test using modes up and down and table/parameter configs

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

LEAFMODE=false # XXX NYI

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fspec=$dir/automode.cli
fin=$dir/in
fstate=$dir/state.xml
fyang=$dir/clixon-example.yang

# Generate autocli for these modules
AUTOCLI=$(autocli_config clixon-example kw-nokey false)

# Use yang in example
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  ${AUTOCLI}
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    /* Generic config data */
    container table{
	list parameter{
	    key name;
	    leaf name{
		type string;
	    }
	    leaf value{
		type string;
	    }
	    leaf stat{
		description "Inline state data for example application";
		config false;
		type int32;
	    }
	}
    }
}
EOF

cat <<EOF > $fspec
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %w> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
edit @datamodelmode, cli_auto_edit("basemodel");
up, cli_auto_up("basemodel");
top, cli_auto_top("basemodel");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") @datamodel, cli_auto_del();
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "text", true, false);{
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
<${DATASTORE_TOP}>
  <table xmlns="urn:example:clixon">
    <parameter>
      <name>a</name>
      <value>42</value>
    </parameter>
  </table>
</${DATASTORE_TOP}>
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
fi

new "wait backend"
wait_backend

# First go down in structure and show config
new "show top tree"
expectpart "$(echo "show config xml" | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>'

cat <<EOF > $fin
up
show config xml
EOF
new "up show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>'

cat <<EOF > $fin
edit table
show config xml
EOF
new "edit table; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table>" "<parameter><name>a</name><value>42</value></parameter>" --not-- '<table xmlns="urn:example:clixon">'

cat <<EOF > $fin
edit table parameter a
show config xml
EOF
new "edit table parameter a; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table/parameter=a/>" "<name>a</name><value>42</value>" --not-- '<table xmlns="urn:example:clixon">' "<parameter>"

if $LEAFMODE; then
cat <<EOF > $fin
edit table
edit parameter
edit a
show config xml
EOF
new "edit table; edit parameter; edit a; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "<name>a</name><value>42</value>" --not-- '<table xmlns="urn:example:clixon">' "<parameter>"
fi

cat <<EOF > $fin
edit table
edit parameter a
show config xml
EOF
new "edit table; edit parameter a; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "<name>a</name><value>42</value>" --not-- '<table xmlns="urn:example:clixon">' "<parameter>"

if $LEAFMODE; then
cat <<EOF > $fin
edit table parameter a value 42
show config xml
EOF
new "edit table parameter a value 42; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 --not-- '<table xmlns="urn:example:clixon">' "<parameter>" "<name>a</name>" "<value>42</value>"
fi

# edit -> top
cat <<EOF > $fin
edit table parameter a value 42
top
show config xml
EOF
new "edit table parameter a value 42; top; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>'

cat <<EOF > $fin
edit table parameter a
top
show config xml
EOF
new "edit table parameter a; top; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>'

# edit -> up

cat <<EOF > $fin
edit table
up
show config xml
EOF
new "edit table; up; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>'

if $LEAFMODE; then
cat <<EOF > $fin
edit table parameter a
up
show config xml
EOF
new "edit table parameter a; up; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table>" "<parameter><name>a</name><value>42</value></parameter>$" --not-- '<table xmlns="urn:example:clixon">'
fi

cat <<EOF > $fin
edit table parameter a
up
up
show config xml
EOF
new "edit table parameter a; up up; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>'

cat <<EOF > $fin
edit table parameter a
up
edit parameter a
show config xml
EOF
new "edit table parameter a; up; edit parameter a; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table/parameter=a/>" "<name>a</name><value>42</value>" --not-- '<table xmlns="urn:example:clixon">' "<parameter>"

# Create new field b, and remove it
cat <<EOF > $fin
edit table parameter b
show config xml
EOF
new "edit table parameter b; show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table/parameter=b/>" --not-- "<name>a</name><value>42</value>"  '<table xmlns="urn:example:clixon">' "<parameter>"

cat <<EOF > $fin
edit table parameter b
set value 71
up
show config xml
EOF
new "set value 71"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table>" "<parameter><name>a</name><value>42</value></parameter><parameter><name>b</name><value>71</value></parameter>"

cat <<EOF > $fin
edit table parameter a
top
edit table parameter b
show config xml
EOF
new "edit parameter b show"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "/clixon-example:table/parameter=b/>" "<name>b</name><value>71</value>" --not-- "<parameter>"

cat <<EOF > $fin
edit table parameter b
delete value 71
show config xml
EOF
new "delete value 71"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "<name>b</name>" --not-- "<value>71</value>"

cat <<EOF > $fin
edit table
delete parameter b
up
show config xml
EOF
new "delete parameter b"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '<table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table>'

# Back to startup
# show state

cat <<EOF > $fin
edit table
show state
EOF
new "show state"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "<parameter><name>a</name><value>42</value><stat>99</stat></parameter>"

# Show other formats
cat <<EOF > $fin
edit table
show config json
EOF
new "show config json"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 '{"clixon-example:parameter":\[{"name":"a","value":"42"}\]}'

cat <<EOF > $fin
edit table
show config text
EOF
new "show config text"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "parameter a {" "value 42;"

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
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><parameter><name>a</name><value>42</value></parameter>" "</config></edit-config></rpc>]]>]]>"

# Negative test
new "config parameter only expect fail"
expectpart "$(echo "set table parameter" | $clixon_cli -f $cfg 2>&1)" 0 "CLI syntax error" "Incomplete command"

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
