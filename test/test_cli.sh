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
clidir=$dir/cli
fyang=$dir/clixon-example.yang

test -d ${clidir} || rm -rf ${clidir}
mkdir $clidir

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
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    import ietf-interfaces { 
	prefix if;
    }
    import ietf-ip {
	prefix ip;
    }
    import iana-if-type {
	prefix ianaift;
    }
    import clixon-autocli{
	prefix autocli;
    }
    /* Example interface type for tests, local callbacks, etc */
    identity eth {
	base if:interface-type;
    }
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
    rpc example {
	description "Some example input/output for testing RFC7950 7.14.
                     RPC simply echoes the input for debugging.";
	input {
	    leaf x {
		description
         	    "If a leaf in the input tree has a 'mandatory' statement with
                   the value 'true', the leaf MUST be present in an RPC invocation.";
		type string;
		mandatory true;
	    }
	    leaf y {
		description
		    "If a leaf in the input tree has a 'mandatory' statement with the
                  value 'true', the leaf MUST be present in an RPC invocation.";
		type string;
		default "42";
	    }
	}
	output {
	    leaf x {
		type string;
	    }
	    leaf y {
		type string;
	    }
	}
    }
}
EOF

cat <<EOF > $clidir/ex.cli
# Clixon example specification
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

set @datamodel, cli_auto_set();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
shell("System command") <source:rest>, cli_start_shell("bash");
copy("Copy and create a new object"){
     interface("Copy interface"){
	(<name:string>|<name:string expand_dbvar("candidate","/ietf-interfaces:interfaces/interface=%s/name")>("name of interface to copy from")) to("Copy to interface") <toname:string>("Name of interface to copy to"), cli_copy_config("candidate","//interface[%s='%s']","urn:ietf:params:xml:ns:yang:ietf-interfaces","name","name","toname");
    }
}
discard("Discard edits (rollback 0)"), discard_changes();
debug("Debugging parts of the system"){
    cli("Set cli debug")	 <level:int32>("Set debug level (0..n)"), cli_debug_cli();
}
show("Show a particular state of the system"){
    xpath("Show configuration") <xpath:string>("XPATH expression") <ns:string>("Namespace"), show_conf_xpath("candidate");
    compare("Compare candidate and running databases"), compare_dbs((int32)0);{
    		     xml("Show comparison in xml"), compare_dbs((int32)0);
		     text("Show comparison in text"), compare_dbs((int32)1);
    }
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "text", true, false);{
	    cli("Show configuration as CLI commands"), cli_auto_show("datamodel", "candidate", "cli", true, false, "set ");
	    xml("Show configuration as XML"), cli_auto_show("datamodel", "candidate", "xml", true, false, "set ");
	    text("Show configuration as TEXT"), cli_auto_show("datamodel", "candidate", "text", true, false, "set ");
  }
}
save("Save candidate configuration to XML file") <filename:string>("Filename (local filename)"), save_config_file("candidate","filename", "xml"){
    cli("Save configuration as CLI commands"), save_config_file("candidate","filename", "cli");
    xml("Save configuration as XML"), save_config_file("candidate","filename", "xml");
    json("Save configuration as JSON"), save_config_file("candidate","filename", "json");
    text("Save configuration as TEXT"), save_config_file("candidate","filename", "text");
}
load("Load configuration from XML file") <filename:string>("Filename (local filename)"),load_config_file("filename", "replace");{
	cli("Replace candidate with file containing CLI commands"), load_config_file("filename", "replace", "cli");
	xml("Replace candidate with file containing XML"), load_config_file("filename", "replace", "xml");
	json("Replace candidate with file containing JSON"), load_config_file("filename", "replace", "json");
	text("Replace candidate with file containing TEXT"), load_config_file("filename", "replace", "text");
}

rpc("example rpc") <a:string>("routing instance"), example_client_rpc("");

# Special cli bug with choice+dbexpand, part1 set db symbol
choicebug {
    <name:string choice:foobar>;
    <name:string expand_dbvar("candidate","/clixon-example:table/parameter/name")>;
}

EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend
    
new "cli configure top"
expectpart "$($clixon_cli -1 -f $cfg set interfaces)" 0 "^$"

new "cli show configuration top (no presence)"
expectpart "$($clixon_cli -1 -f $cfg show conf cli)" 0 "^$"

new "cli configure delete top"
expectpart "$($clixon_cli -1 -f $cfg delete interfaces)" 0 "^$"

new "cli show configuration delete top"
expectpart "$($clixon_cli -1 -f $cfg show conf cli)" 0 "^$"

new "cli configure set interfaces"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth/0/0)" 0 "^$"

new "cli show configuration"
expectpart "$($clixon_cli -1 -f $cfg show conf cli)" 0 "^set interfaces interface eth/0/0" "^set interfaces interface eth/0/0 enabled true"

new "cli configure using encoded chars data <&"
# problems in changing to expectpart with escapes
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth/0/0 description "\"foo<&bar\"")" 0 ""

new "cli configure using encoded chars name <&"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface "fddi&<" type ianaift:ethernetCsmacd)" 0 ""

new "cli failed validate"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 255 "Validate failed. Edit and try again or discard changes: application missing-element Mandatory variable of interface in module ietf-interfaces <bad-element>type</bad-element>"

new "cli configure ip addr"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth/0/0 ipv4 address 1.2.3.4 prefix-length 24)" 0 "^$"

new "cli configure ip descr"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth/0/0 description mydesc)" 0 "^$"

new "cli configure ip type"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth/0/0 type ex:eth)" 0 "^$"

new "cli show xpath description"
expectpart "$($clixon_cli -1 -f $cfg -l o show xpath /interfaces/interface/description urn:ietf:params:xml:ns:yang:ietf-interfaces)" 0 "<description>mydesc</description>"

new "cli delete description"
expectpart "$($clixon_cli -1 -f $cfg -l o delete interfaces interface eth/0/0 description mydesc)" 0 ""

new "cli show xpath no description"
expectpart "$($clixon_cli -1 -f $cfg -l o show xpath /interfaces/interface/description urn:ietf:params:xml:ns:yang:ietf-interfaces)" 0 "^$"

new "cli copy interface"
expectpart "$($clixon_cli -1 -f $cfg copy interface eth/0/0 to eth99)" 0 "^$"

new "cli success validate"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 0 "^$"

new "cli compare diff"
expectpart "$($clixon_cli -1 -f $cfg -l o show compare text)" 0 "+            address 1.2.3.4"

new "cli start shell"
expectpart "$($clixon_cli -1 -f $cfg -l o shell echo foo)" 0 "foo" 

new "cli save"
expectpart "$($clixon_cli -1 -f $cfg -l o save $dir/foo cli)" 0 "^$"

new "cli delete all"
expectpart "$($clixon_cli -1 -f $cfg -l o delete all)" 0 "^$"

new "cli load"
expectpart "$($clixon_cli -1 -f $cfg -l o load $dir/foo cli)" 0 "^$"

new "cli check load"
expectpart "$($clixon_cli -1 -f $cfg -l o show conf cli)" 0 "interfaces interface eth/0/0 ipv4 enabled true"

new "cli debug set"
expectpart "$($clixon_cli -1 -f $cfg -l o debug cli 1)" 0 "^$"

# How to test this?
new "cli debug reset"
expectpart "$($clixon_cli -1 -f $cfg -l o debug cli 0)" 0 "^$"

new "cli rpc"
# We dont know which message-id the cli app uses
expectpart "$($clixon_cli -1 -f $cfg -l o rpc ipv4)" 0 "<rpc-reply $DEFAULTONLY message-id=" "><x xmlns=\"urn:example:clixon\">ipv4</x><y xmlns=\"urn:example:clixon\">42</y></rpc-reply>"

new "cli bug with choice+dbexpand, part1 set db symbol"
expectpart "$($clixon_cli -1 -f $cfg set table parameter foobar)" 0 "^$"

# Here can be error: ambiguous
new "cli bug with choice+dbexpand: part2, make same choice"
expectpart "$($clixon_cli -1 -f $cfg choicebug foobar)" 0 "^$"

new "cli discard"
expectpart "$($clixon_cli -1 -f $cfg discard)" 0 "^$"

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
