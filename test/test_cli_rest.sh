#!/usr/bin/env bash
# CLIgen rest and delimiters test
# Special code for <var:rest> and if the value has delimiters, such as "a b"

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
  leaf description{
      type string;
  }
}
EOF

# clispec files 1..6 for submodes AAA and BBB as described in top comment

cat <<EOF > $clidir/cli1.cli
   CLICON_MODE="example";
   description
    ( <desc:rest>
    | <desc:rest expand_dbvar("candidate","/clixon-example:description")> ),
        cli_set("/clixon-example:description");
    show configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", false, false);
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

new "Add a b"
expectpart "$($clixon_cli -1 -f $cfg description a b)" 0 "^$"

new "Add a b c"
expectpart "$($clixon_cli -1 -f $cfg description a b c)" 0 "^$"

new "Show config"
expectpart "$($clixon_cli -1 -f $cfg show config)" 0 "^<description xmlns=\"urn:example:clixon\">a b c</description>$"

new "Re-add a b c"
expectpart "$($clixon_cli -1 -f $cfg description a b c)" 0 "^$"

new "Show config again"
expectpart "$($clixon_cli -1 -f $cfg show config)" 0 "^<description xmlns=\"urn:example:clixon\">a b c</description>$"

new "Expand <TAB>"
expectpart "$(echo "description 	" | $clixon_cli -f $cfg 2>&1)" 0 "description a b c"

new "Expand a <TAB>"
expectpart "$(echo "description a 	" | $clixon_cli -f $cfg 2>&1)" 0 "description a b c"

new "Show config again"
expectpart "$($clixon_cli -1 -f $cfg show config)" 0 "^<description xmlns=\"urn:example:clixon\">a b c</description>$"

new "Add a b"
expectpart "$($clixon_cli -1 -f $cfg description a b)" 0 "^$"

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
