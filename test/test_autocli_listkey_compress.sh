#!/usr/bin/env bash
# Tests for using the auto cli.
# In particular setting a config, displaying as cli commands and reconfigure it
# Tests:
# Make a config in CLI. Show output as CLI, save it and ensure it is the same
# Try different list-keyword and compress settings (see clixon-autocli.yang)
# NOTE this uses the "Old" autocli (eg cli_set()), see test_cli_auto.sh for "new" autocli using the cli_auto_*() API

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fyang=$dir/$APPNAME.yang
fyang2=$dir/${APPNAME}2.yang
fstate=$dir/state.xml
clidir=$dir/cli
if [ -d $clidir ]; then
    rm -rf $clidir/*
else
    mkdir $clidir
fi

if [ ! -d "$OPENCONFIG" ]; then
#    err "Hmm Openconfig dir does not seem to exist, try git clone https://github.com/openconfig/public?"
    echo "...skipped: OPENCONFIG not set"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi
OCDIR=$OPENCONFIG/release/models

cat <<EOF > $fyang
module $APPNAME {
  namespace "urn:example:clixon";
  prefix ex;
  import openconfig-extensions { prefix oc-ext; }
  /* Set openconfig version to "fake" an openconfig YANG */
  oc-ext:openconfig-version;
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
    }
  }
}
EOF

# For openconfig but NO openconfig extension
cat <<EOF > $fyang2
module ${APPNAME}2 {
  namespace "urn:example:clixon2";
  prefix ex2;
  import openconfig-extensions { prefix oc-ext; }
  container interfaces2 {
    list interface2 {
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
show config, cli_show_config("candidate", "cli", "/", NULL, true, false, NULL,"set ");
show config @datamodel, cli_show_auto("candidate", "cli", true, false, "report-all", "set ");

show state, cli_show_auto_mode("running", "cli", true, true, NULL, "set ");

show state @datamodelstate, cli_show_auto("running", "cli", true, true, "report-all", "set ");
show xml, cli_show_config("candidate", "xml");
show xml @datamodel, cli_show_auto("candidate", "xml");
commit, cli_commit();
discard, discard_changes();

EOF

# Set config for CLI
# 1. listkw   - either none, vars, all
# 2. compress -   surrounding container entities are removed from list nodes
# 3. openconfig - config and state containers are "compressed" out of the schema in openconfig modules
function setconfig()
{
    listkw=$1
    compress=$2
    openconfig=$3

        if $compress; then
COMPRESS=$(cat <<EOF
      <rule>
         <name>compress</name>
         <operation>compress</operation>
         <yang-keyword>container</yang-keyword>
         <yang-keyword-child>list</yang-keyword-child>
      </rule>
EOF
)
    else
        COMPRESS=""
    fi
    if $openconfig; then
OCOMPRESS=$(cat <<EOF
      <rule>
         <name>openconfig compress</name>
         <operation>compress</operation>
         <yang-keyword>container</yang-keyword>
         <schema-nodeid>config</schema-nodeid>
         <!--schema-nodeid>state</schema-nodeid-->
         <!--module-name>openconfig*</module-name-->
         <extension>oc-ext:openconfig-version</extension>
      </rule>"
EOF
)
    else
        OCOMPRESS=""
    fi
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <autocli>
     <module-default>false</module-default>
     <list-keyword-default>${listkw}</list-keyword-default>
     <treeref-state-default>true</treeref-state-default>
     <rule>
       <name>include ${APPNAME}</name>
       <operation>enable</operation>
       <module-name>${APPNAME}*</module-name>
     </rule>
     ${COMPRESS}
     ${OCOMPRESS}
  </autocli>
</clixon-config>
EOF
} # setconfig

new "Set config before backend start"
setconfig kw-nokey false false

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

# Simple run trying setting a config, then deleting it, and reloading it
# Run setconfig first 
# 1. listkw   - either none, vars, all
# 2. compress -   surrounding container entities are removed from list nodes
function testrun()
{
    listkw=$1
    compress=$2

    if [ $listkw = kw-all ]; then
        name=" name"
    else
        name=
    fi
    if $compress; then
        table=
    else
        table=" table"
    fi

    new "set a"
    expectpart "$($clixon_cli -1 -f $cfg set$table parameter$name a value x)" 0 ""
    
    new "set b"
    expectpart "$($clixon_cli -1 -f $cfg set$table parameter$name b value y)" 0 ""

    new "reset b"
    expectpart "$($clixon_cli -1 -f $cfg set$table parameter$name b value z)" 0 ""

    new "show match a & b"
    expectpart "$($clixon_cli -1 -f $cfg show config)" 0 "set$table parameter$name a" "set$table parameter$name a value x" "set$table parameter$name b" "set$table parameter$name b value z" --not-- "set$table parameter$name b value y"

SAVED=$($clixon_cli -1 -f $cfg show config)
# awkward having pretty-printed xml in matching strings

    new "show match a & b xml"
    expectpart "$($clixon_cli -1 -f $cfg show xml)" 0 "<table xmlns=\"urn:example:clixon\">" "<parameter>" "<name>a</name>" "<value>x</value>" "</parameter>" "<parameter>" "<name>b</name>" "<value>z</value>" "</parameter>" "</table>"

    # https://github.com/clicon/clixon/issues/157
    new "delete a y expect fail"
    expectpart "$($clixon_cli -1 -f $cfg delete$table parameter$name a value y 2>&1)" 0 ""

    new "show match a & b xml" # Expect same
    expectpart "$($clixon_cli -1 -f $cfg show xml)" 0 "<table xmlns=\"urn:example:clixon\">" "<parameter>" "<name>a</name>" "<value>x</value>" "</parameter>" "<parameter>" "<name>b</name>" "<value>z</value>" "</parameter>" "</table>"

    new "delete a x"
    expectpart "$($clixon_cli -1 -f $cfg delete$table parameter$name a value x)" 0 ""

    new "show match a & b xml"
    expectpart "$($clixon_cli -1 -f $cfg show xml)" 0 "<table xmlns=\"urn:example:clixon\">" "<parameter>" "<name>a</name>"  "</parameter>" "<parameter>" "<name>b</name>" "<value>z</value>" "</parameter>" "</table>" --not-- "<value>x</value>"

    new "delete a"
    expectpart "$($clixon_cli -1 -f $cfg delete$table parameter$name a)" 0 ""

    new "show match b"
    expectpart "$($clixon_cli -1 -f $cfg show config)" 0  "$table parameter$name b" "$table parameter$name b value z" --not-- "$table parameter$name a" "$table parameter$name a value x" "$table parameter$name b value y"

    new "discard"
    expectpart "$($clixon_cli -1 -f $cfg discard)" 0 ""

    new "show match empty"
    expectpart "$($clixon_cli -1 -f $cfg show config)" 0 --not-- "$table parameter$name b" "$table parameter$name b value z"  "$table parameter$name a" "$table parameter$name a value x" "$table parameter$name b value y"

    new "load saved cli config"
    expectpart "$(echo "$SAVED" | $clixon_cli -f $cfg)" 0 ""

    new "show saved a & b"
    expectpart "$($clixon_cli -1 -f $cfg show config)" 0 "set$table parameter$name a" "set$table parameter$name a value x" "set$table parameter$name b" "set$table parameter$name b value z" --not-- "set$table parameter$name b value y"

    new "discard"
    expectpart "$($clixon_cli -1 -f $cfg discard)" 0 ""
} # testrun

new "Config: Keywords on non-keys"
setconfig kw-nokey false false

new "Keywords on non-keys"
testrun kw-nokey false

new "Config: Keywords on all"
setconfig kw-all false false

new "Keywords on all"
testrun kw-all false

new "Config: Keywords on non-keys, container compress"
setconfig kw-nokey true false

new "Keywords on non-keys, container compress"
testrun kw-nokey true

new "Config:Keywords on non-keys, container and openconfig compress"
setconfig kw-nokey true true

new "Keywords on non-keys, container and openconfig compress"
testrun kw-nokey true

new "Config:default"
setconfig kw-nokey false false

# show state
new "set a"
expectpart "$($clixon_cli -1 -f $cfg set table parameter a value x)" 0 ""

new "commit"
expectpart "$($clixon_cli -1 -f $cfg commit)" 0 ""

new "show state"
expectpart "$($clixon_cli -1 -f $cfg show state)" 0 "exstate sender x" "table parameter a" "table parameter a value x"

new "show state exstate"
expectpart "$($clixon_cli -1 -f $cfg show state exstate)" 0 "state sender x" --not--  "table parameter a" "table parameter a value x"

#---- openconfig path compression

new "Config:Openconfig compression"
setconfig kw-nokey true true

new "Openconfig: OC_COMPRESS+extension: compressed)"
expectpart "$($clixon_cli -1 -f $cfg set interface e enabled true 2>&1)" 0 "^$"

new "Openconfig: OC_COMPRESS+extension: no config (negative)"
expectpart "$($clixon_cli -1 -f $cfg set interface e config enabled true 2>&1)" 255 "Unknown command"

new "Openconfig: OC_COMPRESS+no-extension: no config"
expectpart "$($clixon_cli -1 -f $cfg set interface2 e config enabled true 2>&1)" 0 "^$"

new "Openconfig: OC_COMPRESS+no-extension: no config (negative)"
expectpart "$($clixon_cli -1 -f $cfg set interface2 e enabled true 2>&1)" 255 "Unknown command"

new "Config: default"
setconfig kw-nokey false false

new "Openconfig: OC_VARS+extension: no compresssion"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface e config enabled true 2>&1)" 0 "^$"

new "Openconfig: OC_VARS+extension: no compresssion (negative)"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface e enabled true 2>&1)" 255 "Unknown command"

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
