#!/usr/bin/env bash
# CLIgen output pipe functions with multiple trees and specs
# 1. Multiple pipe files: pipe_common + pipe_show where the latter is a superset
# 2. Implicit pipe and explicit in same file where explicit overrides
# 3. Multiple trees where sub-tree (@datamodel) inherits from treeref

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang
clidir=$dir/clidir
fin=$dir/in

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
CLICON_PIPETREE="|common"; # implicit

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
show("Show a particular state of the system"){
   version("Show version"), cli_show_version("candidate", "text", "/");
   configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", true, false);{
      @|show, cli_show_auto_mode("candidate", "xml", true, false, "report-all");
      @datamodelshow, cli_show_auto("candidate", "xml", true, false, "report-all", "set ", true);
   }
   autocli("Generated tree") @datamodelshow, cli_show_auto("candidate", "xml", true, false, "report-all");
}
EOF

cat <<EOF > $clidir/common.cli
CLICON_MODE="|common:|show";
\| { 
   grep <arg:string>, pipe_grep_fn("-e", "arg");
   except <arg:string>, pipe_grep_fn("-v", "arg");
   tail <arg:string>, pipe_tail_fn("-n", "arg");
   count, pipe_wc_fn("-l");
}
EOF

cat <<EOF > $clidir/show.cli
CLICON_MODE="|show"; # Must start with |
\| { 
   showas {
     xml, pipe_showas_fn("xml");
     json, pipe_showas_fn("json");
     text, pipe_showas_fn("text");
   }
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

# 1. Multiple pipe files: pipe_common + pipe_show where the latter is a superset
new "multiple files: show menu contains common items"
expectpart "$($clixon_cli -1 -f $cfg show configuration \| count)" 0 10

# 2. Implicit pipe and explicit in same file where explicit overrides
new "Implicit default command"
expectpart "$(echo "show version \| ?" | $clixon_cli -f $cfg 2> /dev/null)" 0 count --not-- showas

new "Explicit override"
expectpart "$(echo "show configuration \| ?" | $clixon_cli -f $cfg 2> /dev/null)" 0 count showas

# 3. Multiple trees where sub-tree (@datamodel) inherits from treeref
new "sub-tree default implicit"
expectpart "$(echo "set table \| ?" | $clixon_cli -f $cfg 2> /dev/null)" 0 count --not-- showas

new "sub-tree explicit"
expectpart "$(echo "show configuration table \| ?" | $clixon_cli -f $cfg 2> /dev/null)" 0 count showas

# History error: second command affected by first
# show configuration | count is OK
cat <<EOF > $fin
show configuration table | count
set table | showas xml
EOF
new "Explicit followed by implicit"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "set table | showas xml\": Unknown command" --not-- "<value>a</value>"

cat <<EOF > $fin
set table parameter y value nisse | count
show configuration table | showas xml
EOF
new "Implicit followed by explicit"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 "<value>a</value>" --not-- "Unknown command"

new "subtree two level show"
expectpart "$(echo "show configuration table parameter \| showas xml" | $clixon_cli -f $cfg 2> /dev/null)" 0 "<table xmlns=\"urn:example:clixon\">" "<name>x</name>"

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
