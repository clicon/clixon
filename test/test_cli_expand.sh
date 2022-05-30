#!/usr/bin/env bash
# CLIgen expand
# Especially multi-level expansion, see https://github.com/clicon/clixon/issues/332
# Have not been able to replicate it in cligen test_expand.sh

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
  list list1{
      key  "key1";	  
      leaf key1{
         type string;
      }
      list list2{
         key "key2";
         leaf key2{
            type string;
	 }
      }
   }
}
EOF

# clispec files 1..6 for submodes AAA and BBB as described in top comment

cat <<EOF > $clidir/cli1.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";

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
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "text", true, false);{
      xml("Show configuration as XML"), cli_auto_show("datamodel", "candidate", "xml", false, false);
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

new "Add entry 1 on level2"
expectpart "$($clixon_cli -1 -f $cfg set list1 xyz list2 123)" 0 "^$"

new "Add entry 2 on level2"
expectpart "$($clixon_cli -1 -f $cfg set list1 xyz list2 abc)" 0 "^$"

new "verify"
expectpart "$($clixon_cli -1 -f $cfg show config xml)" 0 '<list1 xmlns="urn:example:clixon"><key1>xyz</key1><list2><key2>123</key2></list2><list2><key2>abc</key2></list2></list1>'

new "Expand ?"
expectpart "$(echo "set list1 xyz list2 ?" | $clixon_cli -f $cfg 2>&1)" 0 123 abc "<key2>"

new "Expand <TAB>"
expectpart "$(echo "set list1 xyz list2 	" | $clixon_cli -f $cfg 2>&1)" 0 123 abc "<key2>"

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
