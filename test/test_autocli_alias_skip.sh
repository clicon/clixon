#!/usr/bin/env bash
# Tests for using autocli skip and alias extension
# Test augment mode only
# Test skip for leaf, container and list
# Test alias only for leaf, since it is not implemented for container+list
# see also test_autocli_hide.sh
set -u
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

: ${clixon_util_datastore:=clixon_util_datastore}

fin=$dir/in
cfg=$dir/conf_yang.xml
fyang=$dir/example.yang
fyang1=$dir/$APPNAME-augment.yang
clidir=$dir/cli
if [ -d $clidir ]; then
    rm -rf $clidir/*
else
    mkdir $clidir
fi

# Use yang in example

# Generate autocli for these modules
AUTOCLI=$(autocli_config ${APPNAME}\* kw-nokey false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  ${AUTOCLI}
</clixon-config>
EOF

cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PIPETREE="|mypipe";

# Autocli syntax tree operations
edit @datamodel, cli_auto_edit("datamodel");
up, cli_auto_up("datamodel");
top, cli_auto_top("datamodel");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
show("Show a particular state of the system") configuration, 
     cli_show_auto_mode("candidate", "xml", false, false);
cli, cli_show_auto_mode("candidate", "cli", false, false);      
EOF
#      @datamodelshow, cli_show_auto("candidate", "xml", false, false, "explicit");

# Yang specs must be here first for backend. But then the specs are changed but just for CLI
# Augment original Yang spec example  directly
# First augment /table/parameter 
# Had a problem with unknown in grouping -> test uses uses/grouping
cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;
  import clixon-autocli{
      prefix autocli;
  }
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      leaf same{
        type string;
      }
      leaf skipped{
        description "leaf skip";
        type string;
      }
      leaf orig{
        description "leaf alias";
        type string;
      }
    }
    list skipped{
       description "list skip";
       key name;
       leaf name{
          type string;
       }
       leaf value{
          type string;
       }
    }
  }
  container skipped{
     description "container skip";
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

# Skip /table/parameter 
cat <<EOF > $fyang1
module example-augment {
   namespace "urn:example:augment";
   prefix aug;
   import example{
      prefix ex;
   }
   import clixon-autocli{
      prefix autocli;
   }
   /* Leafs */
   augment "/ex:table/ex:parameter/ex:skipped" {
      autocli:skip;
   }
   augment "/ex:table/ex:parameter/ex:orig" {
      autocli:alias "alias";
   }
   /* Lists */
   augment "/ex:table/ex:skipped" {
      autocli:skip;
   }
   /* Containers */
   augment "/ex:skipped" {
      autocli:skip;
   }
}
EOF

cat <<EOF > $clidir/clipipe.cli
CLICON_MODE="|mypipe"; # Must start with |
as { 
     xml, pipe_showas_fn("xml", "false");
     cli, pipe_showas_fn("cli", "true", "set ");
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

# Set a value, show it
# Arguments:
# 1 : contorig    Container field shown in xml
# 2 : listorig    List field shown in xml
# 3 : leaforig    Leaf field shown in xml
# 4 : contfield   Container name to set/show
# 5 : listfield   List name to set/show
# 6 : leaffield   Leaf field to set/show
function testok()
{
    contorig=$1
    listorig=$2
    leaforig=$3
    contfield=$4
    listfield=$5
    leaffield=$6

    new "Set $contfield $listfield $leaffield"
    expectpart "$($clixon_cli -1f $cfg set $contfield $listfield x $leaffield abc)" 0 "^$"

    new "Show config as xml"
    expectpart "$($clixon_cli -1f $cfg show config as xml)" 0 "<$contorig xmlns=\"urn:example:clixon\"><$listorig><name>x</name><$leaforig>abc</$leaforig></$listorig></$contorig>"

    new "Show config as cli"
    expectpart "$($clixon_cli -1f $cfg show config as cli)" 0 "set $contfield $listfield x $leaffield abc"

    new "Delete $contfield $listfield $leaffield"
    expectpart "$($clixon_cli -1f $cfg delete $contfield $listfield x $leaffield abc)" 0 "^$"
}

function testfail()
{
    contfield=$1
    listfield=$2
    leaffield=$3

    new "Set $contfield $listfield $leaffield"
#    echo "$clixon_cli -1f -1f $cfg set $contfield $listfield x $leaffield abc"
    expectpart "$($clixon_cli -1f $cfg set  $contfield $listfield x $leaffield abc 2>&1)" 255 "Unknown command"
}

new "wait backend"
wait_backend

# Leaf
new "Test same"
testok table parameter same table parameter same

new "Test leaf skipped"
testfail table parameter skipped

new "Test leaf aliases old fail"
testfail table parameter orig

new "Test leaf aliases new ok"
testok table parameter orig table parameter alias 

# Lists
new "Test list skipped"
testfail table skipped value

# Container
new "Test skipped"
testfail skipped parameter value

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
