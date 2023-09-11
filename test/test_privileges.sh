#!/usr/bin/env bash
# Start clixon backend as root and unprivileged user (clicon)
# Drop privileges from root to clicon
# Test could do more:
# - test file ownership
# - drop_temp check if you can restore

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Dont run this test with valgrind
if [ $valgrindtest -ne 0 ]; then
    echo "...skipped "
    rm -rf $dir
    return 0 # skip
fi

cfg=$dir/conf_startup.xml
fyang=$dir/clixon-example.yang

# Here $dir is created by the user that runs the script

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE> 
  <CLICON_SOCK>/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
}
EOF

# Create a pre-set running, startup and (extra) config.
# The configs are identified by an interface called run, startup, extra.
# Depending on startup mode (init, none, running, or startup)
# expect different output of an initial get-config of running
# Arguments:
# 1: startuser: Start backend as this user
# 2: backend user: Drop to this after initial run as startuser
# 3: expected user: Expected user after drop (or no drop then startuser)
# 4: privileged mode (none, drop_perm, drop_temp)
# 5: expect error: 0 or 1
function testrun(){
    startuser=$1
    beuser=$2
    expectuser=$3
    priv_mode=$4
    expecterr=$5

    # change owner (recursively) of all files in the test dir
    sudo chown -R $startuser $dir

    # change group (recursively) of all files in the test dir
    sudo chgrp -R $startuser $dir

    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err 
    fi
    # Kill all backends regardless of user or pid files (we mess with them in this test)
    sudo pkill -f clixon_backend
    
    # start backend as user

    new "start backend -f $cfg -s init -D $DBG -o CLICON_BACKEND_PRIVILEGES=$priv_mode -o CLICON_BACKEND_USER=$beuser"
    sudo -u $startuser $clixon_backend -f $cfg -s init -D $DBG -o CLICON_BACKEND_PRIVILEGES=$priv_mode -o CLICON_BACKEND_USER=$beuser
    if [ $? -ne 0 ]; then
        err 
    fi
    sleep 1 # wait for backend to exit
    
    pid=$(pgrep -f clixon_backend)    
    if [ $? -ne 0 ]; then
        if [ $expecterr -eq 1 ]; then
            return 0
        fi
        err
    fi

    new "Number of clixon_backend processes"
    c=$(pgrep -c -f clixon_backend)
    if [ $c -ne 1 ]; then
        err 1 $c
    fi

    new "wait backend"
    wait_backend

    if [ $expecterr -eq 1 ]; then
        err "Expected error"
    fi
    
    # Get uid now, and compare with expected user (tail to skip hdr)
    u=$(ps -p $pid -u | tail -1 | awk '{print $1}')
    if [ $u != $expectuser ]; then
        err "$expectuser but user is $u"
    fi

    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
} # testrun

new "Start as non-privileged user, expect same"
testrun $BUSER $BUSER $BUSER none 0

new "Start as privileged user , expect same"
testrun root root root none 0

new "Start as privileged user, drop privileges permanent"
testrun root $BUSER $BUSER drop_perm 0

new "Start as privileged user, drop privileges temporary"
testrun root $BUSER $BUSER drop_temp 0

new "Start as root, drop to root (strange usecase)"
testrun root root root drop_perm 0

new "Start as root, drop to root (strange usecase)"
testrun root root root drop_perm 0

new "Start as root, set user but dont drop (expect still root)"
testrun root $BUSER root none 0

new "Start as non-privileged, try to drop (but fail)"
testrun $(whoami) $BUSER $BUSER drop_perm 1

sudo rm -rf $dir

new "endtest"
endtest
