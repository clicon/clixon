#!/usr/bin/env bash
# Datastore tests:
# - XML and JSON
# - save and load config files

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang
fclispec=$dir/clispec.cli

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
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
        }
    }
}
EOF

cat <<EOF > $fclispec
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %w> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") @datamodel, cli_auto_del();
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
discard("Discard edits (rollback 0)"), discard_changes();

load("Load configuration from XML file") <filename:string>("Filename (local filename)"){
    xml("Replace candidate with file containing XML"), load_config_file("","filename", "replace", "xml");
    json("Replace candidate with file containing JSON"), load_config_file("","filename", "replace", "json");
}
save("Save candidate configuration to XML file") <filename:string>("Filename (local filename)"){
    xml("Save configuration as XML"), save_config_file("candidate","filename", "xml");
    json("Save configuration as JSON"), save_config_file("candidate","filename", "json");
}
show("Show a particular state of the system")
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "xml", false, false);
quit("Quit"), cli_quit();
EOF

# Restconf test routine with arguments:
# 1. format: xml/json
# 2. pretty: false/true - pretty-printed XMLDB
function testrun()
{
    format=$1
    pretty=$2
    
    if [ $BE -ne 0 ]; then
	new "kill old backend"
	sudo clixon_backend -z -f $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s init -f $cfg -o CLICON_XMLDB_FORMAT=$format -o CLICON_XMLDB_PRETTY=$pretty"
	start_backend -s init -f $cfg -o CLICON_XMLDB_FORMAT=$format -o CLICON_XMLDB_PRETTY=$pretty
    fi

    new "wait backend"
    wait_backend

    new "cli configure parameter a"
    expectpart "$($clixon_cli -1 -f $cfg set table parameter a value 42)" 0 "^$"

    new "cli show config xml"
    expectpart "$($clixon_cli -1 -f $cfg show config)" 0 "^<table xmlns=\"urn:example:clixon\"><parameter><name>a</name><value>42</value></parameter></table>$"

    new "Check xmldb $format format"
    # permission kludges
    sudo chmod 666 $dir/candidate_db
    if [ "$format" = xml ]; then
	if [ "$pretty" = false ]; then
	    cat <<EOF > $dir/expect
<${DATASTORE_TOP}><table xmlns="urn:example:clixon"><parameter><name>a</name><value>42</value></parameter></table></${DATASTORE_TOP}>
EOF
	else
	    cat <<EOF > $dir/expect
<${DATASTORE_TOP}>
   <table xmlns="urn:example:clixon">
      <parameter>
         <name>a</name>
         <value>42</value>
      </parameter>
   </table>
</${DATASTORE_TOP}>
EOF
	fi
    else
	if [ "$pretty" = false ]; then
	    cat <<EOF > $dir/expect
{"$DATASTORE_TOP":{"clixon-example:table":{"parameter":[{"name":"a","value":"42"}]}}}
EOF
	else
	    cat <<EOF > $dir/expect
{
  "${DATASTORE_TOP}": {
    "clixon-example:table": {
      "parameter": [
        {
          "name": "a",
          "value": "42"
        }
      ]
    }
  }
}
EOF
	fi
    fi

    # -w ignore white space
    ret=$(diff -w $dir/candidate_db $dir/expect)
    if [ $? -ne 0 ]; then
	err "$(cat $dir/expect)" "$(cat $dir/candidate_db)"
    fi
    
    new "save config file"
    expectpart "$($clixon_cli -1 -f $cfg save $dir/myconfig $format)" 0 "^$"

    new "discard"
    expectpart "$($clixon_cli -1 -f $cfg discard)" 0 "^$"

    new "load config file"
    expectpart "$($clixon_cli -1 -f $cfg load $dir/myconfig $format)" 0 "^$"
    
    new "cli show config xml"
    expectpart "$($clixon_cli -1 -f $cfg show config)" 0 "^<table xmlns=\"urn:example:clixon\"><parameter><name>a</name><value>42</value></parameter></table>$"
    
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

new "test params: -f $cfg"

new "test db xml"
testrun xml false

new "test db xml pretty"
testrun xml true

new "test db json"
testrun json false

new "test db json pretty"
testrun json true

rm -rf $dir

unset format
unset pid
unset ret

new "endtest"
endtest
