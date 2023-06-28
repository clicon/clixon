#!/usr/bin/env bash
# CLIgen output pipe functions
# Note, | must be escaped as \| otherwise shell's pipe is used (w possibly same result)
# XXX Autocli does not work

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang
clidir=$dir/clidir

if [ ! -d $clidir ]; then
    mkdir $clidir
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
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

cat <<EOF > $clidir/example.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";

# Autocli syntax tree operations
edit @datamodel, cli_auto_edit("datamodel");
up, cli_auto_up("datamodel");
top, cli_auto_top("datamodel");
set @datamodel, cli_auto_set();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
commit("Commit the changes"), cli_commit();

EOF

cat <<EOF > $clidir/nodefault.cli
CLICON_MODE="nodefault";
CLICON_PROMPT="%U@%H %W> ";

show("Show a particular state of the system"){
   implicit("No pipe function") {
      configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", true, false);
   }
   explicit("Explicit pipe function") {
      configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", true, false);{
         @|mypipe, cli_show_auto_mode("candidate", "xml", true, false);
      }
   }
   autocli("Generated tree") @datamodelshow, cli_show_auto("candidate", "xml", true, false, "report-all");
   treeref @treeref;
}
EOF

cat <<EOF > $clidir/default.cli
CLICON_MODE="default";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PIPETREE="|mypipe";  # Only difference from nodefault

show("Show a particular state of the system"){
   implicit("No pipe function") {
      configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", true, false);
   }
   explicit("Explicit pipe function") {
      configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", true, false);{
         @|mypipe, cli_show_auto_mode("candidate", "xml", true, false);
      }
   }
   autocli("Generated tree") @datamodelshow, cli_show_auto("candidate", "xml", true, false, "report-all");
   treeref @treeref;
}
EOF

cat <<EOF > $clidir/treeref.cli
CLICON_MODE="treeref";
CLICON_PIPETREE="|mypipe";

implicit("Show configuration"), cli_show_auto_mode("candidate", "xml", true, false);
explicit("Show configuration"), cli_show_auto_mode("candidate", "xml", true, false);{
    @|mypipe, cli_show_auto_mode("candidate", "xml", true, false);
}

EOF

cat <<EOF > $clidir/clipipe.cli
CLICON_MODE="|mypipe"; # Must start with |
#CLICON_PIPETREE="|mypipe";
\| { 
   grep <arg:rest>, grep_fn("grep -e", "arg");
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

new "Add entry x"
expectpart "$($clixon_cli -1 -f $cfg set table parameter x value a)" 0 "^$"

new "Add entry y"
expectpart "$($clixon_cli -1 -f $cfg set table parameter y value b)" 0 "^$"

new "Commit"
expectpart "$($clixon_cli -1 -f $cfg commit)" 0 "^$"

new "Pipes with no default rule"
mode=nodefault

new "$mode show implicit"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show implicit config)" 0 "<parameter>" "</parameter>" "table" "value"

new "$mode show explicit"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show explicit config)" 0 "<parameter>" "</parameter>" "table" "value"

new "$mode show implicit | grep par"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show implicit config \| grep par 2>&1)" 255 "Unknown command"

new "$mode show explicit | grep par , expect fail"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show explicit config \| grep par)" 0 "<parameter>" "</parameter>" --not-- "table" "value"

new "$mode show treeref explicit | grep par"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show treeref explicit \| grep par)" 0 "<parameter>" "</parameter>" --not-- "table" "value"

# No-default top-level rule also applies to sub-tree, feature or bug?
new "$mode show treeref implicit | grep par, expect error"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show treeref implicit \| grep par 2>&1)" 255 "Unknown command"

# No-default top-level rule also applies to sub-tree, feature or bug?
new "$mode show autocli table | grep par, expect error"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show autocli table \| grep par 2>&1)" 255 "Unknown command"

new "Pipes with default rule"
mode=default

new "$mode show implicit"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show implicit config)" 0 "<parameter>" "</parameter>" "table" "value"

new "$mode show explicit"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show explicit config)" 0 "<parameter>" "</parameter>" "table" "value"

new "$mode show implicit | grep par"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show implicit config \| grep par 2>&1)" 0 "<parameter>" "</parameter>" --not-- "table" "value"

new "$mode show explicit | grep par"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show explicit config \| grep par)" 0 "<parameter>" "</parameter>" --not-- "table" "value"

new "$mode show treeref explicit | grep par"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show treeref explicit \| grep par)" 0 "<parameter>" "</parameter>" --not-- "table" "value"

new "$mode show treeref implicit | grep par"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show treeref implicit \| grep par)" 0 "<parameter>" "</parameter>" --not-- "table" "value"

new "$mode show autocli table | grep par"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show autocli table \| grep par 2>&1)" 0 "<parameter>" "</parameter>" --not-- "table" "value"

new "$mode show autocli table parameter x value | grep value"
expectpart "$($clixon_cli -1 -m $mode -f $cfg show autocli table parameter x value \| grep value)" 0 "<value>a</value>" --not-- "table" "parameter"

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

unset mode

new "endtest"
endtest
