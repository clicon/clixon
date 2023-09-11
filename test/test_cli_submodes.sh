#!/usr/bin/env bash
# CLIgen mode tests
# Have two modes: AAA and BBB 
# Have the following clispec files with syntax for:
# 1) * 2) AAA, 3) BBB, 4) CCC, 5) AAA:BBB, 6) BBB:CCC
# Verify then that modes AAA and BBB have right syntax (also negative)
# AAA should have syntax from 1,2,5 (and not 3,4,6)
# BBB should have syntax from 1,3,5,6 (and not 2,4)

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
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
}
EOF

# clispec files 1..6 for submodes AAA and BBB as described in top comment

cat <<EOF > $clidir/cli1.cli
   CLICON_MODE="*";
   cmd1;
EOF

cat <<EOF > $clidir/cli2.cli
   CLICON_MODE="AAA";
   cmd2;
EOF

cat <<EOF > $clidir/cli3.cli
   CLICON_MODE="BBB";
   cmd3;
EOF

cat <<EOF > $clidir/cli4.cli
   CLICON_MODE="CCC";
   cmd4;
EOF

cat <<EOF > $clidir/cli5.cli
   CLICON_MODE="AAA:BBB";
   cmd5;
EOF

cat <<EOF > $clidir/cli6.cli
   CLICON_MODE="BBB:CCC";
   cmd6;
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

m=AAA
# Tests using mode AAA that should pass
for c in 1 2 5; do
    new "cli mode $m 1 cmd$c OK"
    expectpart "$($clixon_cli -1 -m $m -f $cfg cmd$c)" 0 "^$"
done
# Tests using mode AAA that should fail
for c in 3 4 6; do
    new "cli mode $m 1 cmd$c Expect fail"
    expectpart "$($clixon_cli -1 -m $m -f $cfg cmd$c)" 255 "^$"
done

m=BBB
# Tests using mode BBB that should pass
for c in 1 3 5 6; do
    new "cli mode $m 1 cmd$c OK"
    expectpart "$($clixon_cli -1 -m $m -f $cfg cmd$c)" 0 "^$"
done
# Tests using mode BBB that should fail
for c in 2 4; do
    new "cli mode $m 1 cmd$c Expect fail"
    expectpart "$($clixon_cli -1 -m $m -f $cfg cmd$c)" 255 "^$"
done

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
