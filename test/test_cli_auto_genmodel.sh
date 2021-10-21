
#!/usr/bin/env bash
# Tests for using the auto cli.
# In particular setting a config, displaying as cli commands and reconfigure it
# Tests:
# Make a config in CLI. Show output as CLI, save it and ensure it is the same
# Try the different GENMODEL settings
# NOTE this uses the "Old" autocli (eg cli_set()), see test_cli_auto.sh for "new" autocli using the cli_auto_*() API

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fyang=$dir/$APPNAME.yang
fstate=$dir/state.xml
clidir=$dir/cli
if [ -d $clidir ]; then
    rm -rf $clidir/*
else
    mkdir $clidir
fi

# Use yang in example

if [ ! -d "$OPENCONFIG" ]; then
#    err "Hmm Openconfig dir does not seem to exist, try git clone https://github.com/openconfig/public?"
    echo "...skipped: OPENCONFIG not set"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

OCDIR=$OPENCONFIG/release/models

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_GENMODEL>2</CLICON_CLI_GENMODEL>
  <CLICON_CLI_GENMODEL_TYPE>VARS</CLICON_CLI_GENMODEL_TYPE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_CLI_AUTOCLI_EXCLUDE>clixon-restconf</CLICON_CLI_AUTOCLI_EXCLUDE>
</clixon-config>
EOF

cat <<EOF > $fyang
module $APPNAME {
  namespace "urn:example:clixon";
  prefix ex;
  import openconfig-extensions { prefix oc-ext; }
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
  container exstate{
    config false;
    list sender{
      key ref;
      leaf ref{
        type string;
      }
    }
  }
  container interfaces {
    oc-ext:openconfig-version;
    list interface {
      key name;
      leaf name {
       type string;
      }
      container config {
	leaf enabled {
	  type boolean;
	  default false;
	  description "Whether the interface is enabled or not.";
	}
      }
      container state {
	config false;
	leaf oper-status {
	  type enumeration {
	    enum UP {
	      value 1;
	      description "Ready to pass packets.";
	    }
	    enum DOWN {
	      value 2;
	      description "The interface does not pass any packets.";
	    }
	  }
	}
      }
      leaf enabled {
	type boolean;
	default false;
	description "Whether the interface is enabled or not.";
      }
    }
  }
}
EOF

# This is state data written to file that backend reads from (on request)
cat <<EOF > $fstate
   <exstate xmlns="urn:example:clixon">
     <sender>
       <ref>x</ref>
     </sender>
   </exstate>
EOF

cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H> ";

set @datamodel, cli_set();
merge @datamodel, cli_merge();
create @datamodel, cli_create();
delete @datamodel, cli_del();
show config, cli_show_config("candidate", "cli", "/", 0, "set ");
show config @datamodel, cli_show_auto("candidate", "cli", "set ");
show state, cli_show_config_state("running", "cli", "/", "set ");
show state @datamodelstate, cli_show_auto_state("running", "cli", "set ");
show xml, cli_show_config("candidate", "xml", "/");
show xml @datamodel, cli_show_auto("candidate", "xml");
commit, cli_commit();
discard, discard_changes();

EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg -- -sS $fstate"
    start_backend -s init -f $cfg -- -sS $fstate
fi

new "wait backend"
wait_backend

# Simple run trying setting a config,
# then deleting it, and reloading it
# 1. mode - either VARS Keywords on non-key variables: a <x> y <y> or
#                  ALL  Keywords on all variables: a x <x> y <y>
function testrun()
{
    mode=$1
    if [ $mode = ALL ]; then
	table=" table"
	name=" name"
    elif [ $mode = HIDE ]; then
	table=
	name=
    elif [ $mode = OC_COMPRESS ]; then
	table=
	name=
    else
	table=" table"
	name=
    fi

    new "set a"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg set$table parameter$name a value x)" 0 ""

    new "set b"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg set$table parameter$name b value y)" 0 ""

    new "reset b"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg set$table parameter$name b value z)" 0 ""

    new "show match a & b"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg show config)" 0 "set$table parameter$name a" "set$table parameter$name a value x" "set$table parameter$name b" "set$table parameter$name b value z" --not-- "set$table parameter$name b value y"
SAVED=$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg show config)
# awkward having pretty-printed xml in matching strings

    new "show match a & b xml"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg show xml)" 0 "<table xmlns=\"urn:example:clixon\">" "<parameter>" "<name>a</name>" "<value>x</value>" "</parameter>" "<parameter>" "<name>b</name>" "<value>z</value>" "</parameter>" "</table>"

    # https://github.com/clicon/clixon/issues/157
    new "delete a y expect fail"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg delete$table parameter$name a value y 2>&1)" 0 ""

    new "show match a & b xml" # Expect same
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg show xml)" 0 "<table xmlns=\"urn:example:clixon\">" "<parameter>" "<name>a</name>" "<value>x</value>" "</parameter>" "<parameter>" "<name>b</name>" "<value>z</value>" "</parameter>" "</table>"

    new "delete a x"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg delete$table parameter$name a value x)" 0 ""

    new "show match a & b xml"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg show xml)" 0 "<table xmlns=\"urn:example:clixon\">" "<parameter>" "<name>a</name>"  "</parameter>" "<parameter>" "<name>b</name>" "<value>z</value>" "</parameter>" "</table>" --not-- "<value>x</value>"

    new "delete a"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg delete$table parameter$name a)" 0 ""

    new "show match b"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg show config)" 0  "$table parameter$name b" "$table parameter$name b value z" --not-- "$table parameter$name a" "$table parameter$name a value x" "$table parameter$name b value y"

    new "discard"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg discard)" 0 ""

    new "show match empty"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg show config)" 0 --not-- "$table parameter$name b" "$table parameter$name b value z"  "$table parameter$name a" "$table parameter$name a value x" "$table parameter$name b value y"

    new "load saved cli config"
    expectpart "$(echo "$SAVED" | $clixon_cli -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg)" 0 ""

    new "show saved a & b"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg show config)" 0 "set$table parameter$name a" "set$table parameter$name a value x" "set$table parameter$name b" "set$table parameter$name b value z" --not-- "set$table parameter$name b value y"

    new "discard"
    expectpart "$($clixon_cli -1 -o CLICON_CLI_GENMODEL_TYPE=$mode -f $cfg discard)" 0 ""
} # testrun

new "keywords=HIDE"
testrun HIDE

new "keywords=ALL"
testrun ALL

new "keywords=OC_COMPRESS"
testrun OC_COMPRESS

new "keywords=VARS"
testrun VARS

# show state
new "set a"
expectpart "$($clixon_cli -1 -f $cfg set$table parameter a value x)" 0 ""

new "commit"
expectpart "$($clixon_cli -1 -f $cfg commit)" 0 ""

new "show state"
expectpart "$($clixon_cli -1 -f $cfg show state)" 0 "exstate sender x" "table parameter a" "table parameter a value x"

new "show state exstate"
expectpart "$($clixon_cli -1 -f $cfg show state exstate)" 0 "state sender x" --not--  "table parameter a" "table parameter a value x"

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir

new "endtest"
endtest
