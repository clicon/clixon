#!/usr/bin/env bash
# test for cli when CLICON_CLI_VARONLY is 0
# I.e., INCLUDE keys

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf.xml
fyang=$dir/example.yang

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_VARONLY>0</CLICON_CLI_VARONLY>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example {
   yang-version 1.1;
   namespace "urn:example:example";
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

new "cli set 42 include keys"
expectpart "$($clixon_cli -1 -o CLICON_CLI_VARONLY=0 -f $cfg set table parameter 42)" 0 "^$"

new "cli set 43 exclude keys"
expectpart "$($clixon_cli -1 -o CLICON_CLI_VARONLY=1 -f $cfg set table parameter 43)" 0 "^$"

new "cli show 42 43 include"
expectpart "$($clixon_cli -1 -o CLICON_CLI_VARONLY=0 -f $cfg show conf cli)" 0 "set table parameter 42" "set table parameter 43"

new "cli show 42 43 exclude"
expectpart "$($clixon_cli -1 -o CLICON_CLI_VARONLY=1 -f $cfg show conf cli)" 0 "set table parameter 42" "set table parameter 43"

new "cli expand include keys"
expectpart "$(echo "set table parameter ?" | $clixon_cli -o CLICON_CLI_VARONLY=0 -f $cfg 2>&1)" 0 42 43

new "cli expand exclude keys"
expectpart "$(echo "set table parameter ?" | $clixon_cli -o CLICON_CLI_VARONLY=1 -f $cfg 2>&1)" 0 42 43

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
