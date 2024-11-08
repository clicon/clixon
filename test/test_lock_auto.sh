#!/usr/bin/env bash
# Test autolock functionality

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Dont run this test with valgrind
if [ $valgrindtest -ne 0 ]; then
    echo "...skipped "
    rm -rf $dir
    return 0 # skip
fi

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
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_AUTOLOCK>true</CLICON_AUTOLOCK>
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
set @datamodel, cli_auto_set();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del();
      all("Delete whole candidate configuration"), delete_all("candidate");
}
commit("Commit the changes"), cli_commit();
discard("Discard edits (rollback 0)"), discard_changes();
show("Show a particular state of the system"){
configuration("Show configuration"), cli_show_auto_mode("candidate", "default", true, false, "explicit", "set ");
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

# Maybe could use mkfifo:
# mkfifo $dir/cli1
# cat > $dir/cli1 &
# clixon_cli < $dir/cli1 &
# echo "show devices" > $dir/cli1

if false; then
    mkfifo $dir/cli1
#    cat > $dir/cli1 &
    $clixon_cli -f $cfg < $dir/cli1 &
    new "cli 1st edit async"
    echo "set table parameter x value a" > $dir/cli1
    jobs -l %
    PIDS=($(jobs -l % | cut -c 6- | awk '{print $1}'))
#    echo "PIDS:$PIDS"

    new "cli 2nd edit expect fail"
    expectpart "$($clixon_cli -1f $cfg set table parameter y value b 2>&1)" 255 "lock-denied" "lock is already held"

    kill ${PIDS[0]}                   # kill the while loop above to close STDIN on 1st
    wait

    new "cli 3rd edit expect ok"
expectpart "$($clixon_cli -1f $cfg set table parameter z value c)" 0 "^$"
else
new "cli 1st edit async"
sleep 60 | expectpart "$($clixon_cli -f $cfg set table parameter x value a)" 0 "" &
if [ $valgrindtest -eq 1 ]; then
    sleep 1
fi
PIDS=($(jobs -l % | cut -c 6- | awk '{print $1}'))

new "cli 2nd edit expect fail"
expectpart "$($clixon_cli -1f $cfg set table parameter y value b 2>&1)" 255 "lock-denied" "lock is already held"

kill ${PIDS[0]}                   # kill the while loop above to close STDIN on 1st
wait

new "cli 3rd edit expect ok"
expectpart "$($clixon_cli -1f $cfg set table parameter z value c)" 0 "^$"

new "cli 1st edit;commit async"
sleep 60 | expectpart "$($clixon_cli -f $cfg set table parameter x value a \; commit)" 0 "" &
sleep 1
PIDS=($(jobs -l % | cut -c 6- | awk '{print $1}'))

new "cli edit 2nd expected ok"
expectpart "$($clixon_cli -1f $cfg set table parameter x value a)" 0 "^$"

kill ${PIDS[0]}                   # kill the while loop above to close STDIN on 1st
wait

new "cli 1st edit;discard async"
sleep 60 | expectpart "$($clixon_cli -f $cfg set table parameter x value a \; discard)" 0 "" &
if [ $valgrindtest -eq 1 ]; then
    sleep 1
fi
PIDS=($(jobs -l % | cut -c 6- | awk '{print $1}'))

new "cli edit 2nd expected ok"
expectpart "$($clixon_cli -1f $cfg set table parameter x value a)" 0 "^$"
fi
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
