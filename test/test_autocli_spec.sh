#!/usr/bin/env bash
# Test of clixon-clispec.yang and cli_clispec.[ch]

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
clispec=$dir/automode.cli
fin=$dir/in
fstate=$dir/state.xml
fyang=$dir/clixon-example.yang
fyang2=$dir/clixon-example2.yang

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

cat <<EOF > $fyang2
module clixon-example2 {
    yang-version 1.1;
    namespace "urn:example:clixon2";
    prefix ex2;
    /* Alt config data */
    container table2{
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

cat <<EOF > $clispec
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
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

# Make a new variant of clixon config file
# Arg 1: autocli-spec
function runconfig()
{
    AUTOCLI="$1"

# Use yang in example
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
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
}

new "backend config"
runconfig ""

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

AUTOCLI=$(cat <<EOF
  <autocli>
     <module-default>false</module-default>
  </autocli>
EOF
)
new "disable autocli"
runconfig "$AUTOCLI"

new "set table expected fail"
expectpart "$(echo "set table" | $clixon_cli -f $cfg 2>&1)" 255 "CLIgen tree 'datamodel' not found"

AUTOCLI=$(cat <<EOF
  <autocli>
     <module-default>true</module-default>
  </autocli>
EOF
)

new "enable autocli"
runconfig "$AUTOCLI"

new "set table OK"
expectpart "$(echo "set table" | $clixon_cli -f $cfg 2>&1)" 0 ""

AUTOCLI=$(cat <<EOF
  <autocli>
     <module-default>false</module-default>
     <rule>
       <name>include example</name>
       <operation>enable</operation>
       <description>Include the example module for autocli generation</description>
       <module-name>clixon-example</module-name>
     </rule>
  </autocli>
EOF
)

new "exclude example2 using default"
runconfig "$AUTOCLI"

new "set table"
expectpart "$(echo "set table" | $clixon_cli -f $cfg 2>&1)" 0 ""

new "set table2 expect fail"
expectpart "$(echo "set table2" | $clixon_cli -f $cfg 2>&1)" 0 "CLI syntax error" "Unknown command"

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
