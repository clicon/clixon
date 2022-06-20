#!/usr/bin/env bash
# Datastore format tests
# Go through all formats and save and load a simple config via the CLI
# Add as appropriate

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
clidir=$dir/cli

fyang=$dir/clixon-example.yang
fyang1=$dir/clixon-augment.yang

formatdir=$dir/format
test -d ${formatdir} || rm -rf ${formatdir}
mkdir $formatdir

test -d ${clidir} || rm -rf ${clidir}
mkdir $clidir

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
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
	    leaf-list array1{
	      type string;
            }
/*	    leaf-list array2{
	      type string;
            }	    
*/
	}
    }
}
EOF

cat <<EOF > $fyang1
module clixon-augment {
    yang-version 1.1;
    namespace "urn:example:augment";
    prefix aug;
    import clixon-example {
       prefix ex;
    }
    augment "/ex:table/ex:parameter" {
        leaf-list array2{
	      type string;
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
discard("Discard edits (rollback 0)"), discard_changes();
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

# For formats, create three leaf-lists
new "cli create leaflist array1 a"
expectpart "$($clixon_cli -1 -f $cfg -l o set table parameter a array1 a)" 0 "^$"

new "cli create leaflist array1 b1 b2"
expectpart "$($clixon_cli -1 -f $cfg -l o set table parameter a array1 \"b1 b2\")" 0 "^$"

new "cli create leaflist array2 c1 c2"
expectpart "$($clixon_cli -1 -f $cfg -l o set table parameter a array2 \"c1 c2\")" 0 "^$"

new "cli commit"
expectpart "$($clixon_cli -1 -f $cfg -l o commit)" 0 "^$"

for format in cli text xml json; do
    new "cli save $format"
    expectpart "$($clixon_cli -1 -f $cfg -l o save $formatdir/config.$format $format)" 0 "^$"

    new "cli delete all"
    expectpart "$($clixon_cli -1 -f $cfg -l o delete all)" 0 "^$"

    new "cli load $format"
    expectpart "$($clixon_cli -1 -f $cfg -l o load $formatdir/config.$format $format)" 0 "^$"

    if [ $format != json ]; then # XXX JSON identity problem
	new "cli check compare $format"
	expectpart "$($clixon_cli -1 -f $cfg -l o show compare xml)" 0 "^$" --not-- "i" # interface?
    fi

done

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
