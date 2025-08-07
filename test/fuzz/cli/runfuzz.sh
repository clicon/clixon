#!/usr/bin/env bash
# Run a fuzzing test using american fuzzy lop
set -eux

if [ $# -ne 0 ]; then 
    echo "usage: $0\n"
    exit 255
fi

APPNAME=example
cfg=conf.xml
CFD=conf.d
test -d $CFD || mkdir -p $CFD
test -d clispec || mkdir -p clispec

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_CONFIGDIR>$CFD</CLICON_CONFIGDIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/example/example.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_CLISPEC_DIR>clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_CLI_TAB_MODE>0</CLICON_CLI_TAB_MODE>
</clixon-config>
EOF

cat <<EOF > $CFD/autocli.xml
<clixon-config xmlns="http://clicon.org/config">
  <autocli>
     <module-default>false</module-default>
     <rule>
       <name>include $APPNAME</name>
       <operation>enable</operation>
       <module-name>clixon-example</module-name>
     </rule>
  </autocli>
</clixon-config>
EOF

cat <<EOF > clispec/example.cli
# Clixon example specification
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
edit @datamodelmode, cli_auto_edit("basemodel");
up, cli_auto_up("basemodel");
top, cli_auto_top("basemodel");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit(); {
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

copy("Copy and create a new object") {
    running("Copy from running db")  startup("Copy to startup config"), db_copy("running", "startup");
    interface("Copy interface"){
	(<name:string>|<name:string expand_dbvar("candidate","/ietf-interfaces:interfaces/interface=%s/name")>("name of interface to copy from")) to("Copy to interface") <toname:string>("Name of interface to copy to"), cli_copy_config("candidate","//interface[%s='%s']","urn:ietf:params:xml:ns:yang:ietf-interfaces","name","name","toname");
    }
}
discard("Discard edits (rollback 0)"), discard_changes();

show("Show a particular state of the system"){
    auto("Show expand x"){
      xml @datamodelshow, cli_show_auto("candidate", "xml", true, false, "report-all");
      text @datamodelshow, cli_show_auto("candidate", "text", true, false, "report-all");
      json @datamodelshow, cli_show_auto("candidate", "json", true, false, "report-all");
      netconf @datamodelshow, cli_show_auto("candidate", "netconf", true, false, "report-all");
      cli @datamodelshow, cli_show_auto("candidate", "cli", true, false, "report-all", "set ");
    }
    xpath("Show configuration") <xpath:string>("XPATH expression")
       [<ns:string>("Namespace")], show_conf_xpath("candidate");
    version("Show version"), cli_show_version("candidate", "text", "/");
    options("Show clixon options"), cli_show_options();
    compare("Compare candidate and running databases"), compare_dbs("running", "candidate", "xml");{
    		     xml("Show comparison in xml"), compare_dbs("running", "candidate", "xml");
		     text("Show comparison in text"), compare_dbs("running", "candidate", "text");
    }
    pagination("Show list pagination") xpath("Show configuration") <xpath:string>("XPATH expression"){
    	xml, cli_pagination("use xpath var", "es", "http://example.com/ns/example-social", "xml", "10");
	cli, cli_pagination("use xpath var", "es", "http://example.com/ns/example-social", "cli", "10");
	text, cli_pagination("use xpath var", "es", "http://example.com/ns/example-social", "text", "10");
	json, cli_pagination("use xpath var", "es", "http://example.com/ns/example-social", "json", "10");
    }
    configuration("Show configuration"), cli_show_auto_mode("candidate", "text", true, false);{
	    xml("Show configuration as XML"), cli_show_auto_mode("candidate", "xml", true, false);{
	       default("With-default mode"){
	          report-all, cli_show_auto_mode("candidate", "xml", true, false, "report-all");
		  trim, cli_show_auto_mode("candidate", "xml", true, false, "trim");
		  explicit, cli_show_auto_mode("candidate", "xml", true, false, "explicit");
		  report-all-tagged, cli_show_auto_mode("candidate", "xml", true, false, "report-all-tagged");
		  report-all-tagged-default, cli_show_auto_mode("candidate", "xml", true, false, "report-all-tagged-default");
		  report-all-tagged-strip, cli_show_auto_mode("candidate", "xml", true, false, "report-all-tagged-strip");
	       }
	    }
	    cli("Show configuration as CLI commands"), cli_show_auto_mode("candidate", "cli", true, false, "explicit", "set ");
	    netconf("Show configuration as netconf edit-config operation"), cli_show_auto_mode("candidate", "netconf", true, false);
	    text("Show configuration as text"), cli_show_auto_mode("candidate", "text", true, false);
	    json("Show configuration as JSON"), cli_show_auto_mode("candidate", "json", true, false);
 
    }
    state("Show configuration and state"), cli_show_auto_mode("running", "text", true, true); {
    	    xml("Show configuration and state as XML"), cli_show_auto_mode("running", "xml", true, true);{
	    default("With-default mode"){
	     	  report-all, cli_show_auto_mode("running", "xml", true, true, "report-all");
		  trim, cli_show_auto_mode("running", "xml", true, true, "trim");
		  explicit, cli_show_auto_mode("running", "xml", true, true, "explicit");
		  report-all-tagged, cli_show_auto_mode("running", "xml", true, true, "report-all-tagged");
		  report-all-tagged-default, cli_show_auto_mode("running", "xml", true, true, "report-all-tagged-default");
		  report-all-tagged-strip, cli_show_auto_mode("running", "xml", true, true, "report-all-tagged-strip");
	    }
        }
    }
    yang("Show yang specs"), show_yang(); {
        clixon-example("Show clixon-example yang spec"), show_yang("clixon-example");
    }		   
    statistics("Show statistics"), cli_show_statistics();{
      brief, cli_show_statistics();
      modules, cli_show_statistics("modules");
    }
}
load("Load configuration from XML file") <filename:string>("Filename (local filename)"),load_config_file("filename", "replace");{
    replace("Replace candidate with file contents"), load_config_file("filename", "replace");{
	cli("Replace candidate with file containing CLI commands"), load_config_file("filename", "replace", "cli");
	xml("Replace candidate with file containing XML"), load_config_file("filename", "replace", "xml");
	json("Replace candidate with file containing JSON"), load_config_file("filename", "replace", "json");
	text("Replace candidate with file containing TEXT"), load_config_file("filename", "replace", "text");
    }
    merge("Merge file with existent candidate"), load_config_file("filename", "merge");{
	cli("Merge candidate with file containing CLI commands"), load_config_file("filename", "merge", "cli");
	xml("Merge candidate with file containing XML"), load_config_file("filename", "merge", "xml");
	json("Merge candidate with file containing JSON"), load_config_file("filename", "merge", "json");
	text("Merge candidate with file containing TEXT"), load_config_file("filename", "merge", "text");
    }
}
example("This is a comment") <var:int32>("Just a random number"), mycallback("myarg");
rpc("example rpc") <a:string>("routing instance"), example_client_rpc("");
notify("Get notifications from backend"), cli_notify("EXAMPLE", "1", "text");
no("Negate") notify("Get notifications from backend"), cli_notify("EXAMPLE", "0", "xml");
lock,cli_lock("candidate");
unlock,cli_unlock("candidate");
restart <plugin:string>, cli_restart_plugin();
EOF

# Kill previous
sudo clixon_backend -z -f $cfg -s init 

# Start backend
sudo clixon_backend -f $cfg -s init

MEGS=500 # memory limit for child process (50 MB)

# remove input and input dirs XXX
#test ! -d input || rm -rf input
test ! -d output || rm -rf output

# create if dirs dont exists
#test -d input || mkdir input
test -d output || mkdir output

# Run script 
afl-fuzz -i input -o output -m $MEGS -- /usr/local/bin/clixon_cli -f $cfg
