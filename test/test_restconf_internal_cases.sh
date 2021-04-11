#!/usr/bin/env bash
# Send restconf rpc:s when starting from backend
# Two specific usecases that have been problematic are tested here
# In comparison test_restconf_internal.sh:
# - uses externally started restconf, here started by backend
# - generic tests, here specific
# The first usecases is: empty status message
#   1. Start a minimal restconf
#   2. Kill it externally (or it exits)
#   3. Start a server
#   4. Query status (Error message is returned)
# The second usecase is: zombie process on exit
#   1. Start server with bad address
#   2. Zombie process appears
# The third usecase is: restconf not removed
#   1. Start server
#   2. Remove server
#   3. Check status (Error: still up)

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
startupdb=$dir/startup_db

# Restconf debug
RESTCONFDBG=$DBG
RCPROTO=http # no ssl here

if [ "${WITH_RESTCONF}" = "fcgi" ]; then
    EXTRACONF="<CLICON_FEATURE>clixon-restconf:fcgi</CLICON_FEATURE>"
else
    EXTRACONF=""
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  $EXTRACONF
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
  <!-- start restconf from backend -->
  <CLICON_BACKEND_RESTCONF_PROCESS>true</CLICON_BACKEND_RESTCONF_PROCESS>
</clixon-config>
EOF

cat <<EOF > $dir/example.yang
module example {
   namespace "urn:example:clixon";
   prefix ex;
   revision 2021-03-05;
   leaf val{
      type string;
   }
}
EOF

# Subroutine send a process control RPC and tricks to echo process-id returned
# Args, expected values of:
# 0: ACTIVE: true or false
# 1: STATUS: stopped/running/exiting
# retvalue:
# $pid
# See also in test_restconf_internal.sh
function rpcstatus()
{
    if [ $# -ne 2 ]; then
	err1 "rpcstatus: # arguments: 2" "$#"
    fi
    active=$1
    status=$2
    
    sleep $DEMSLEEP
    new "send rpc status"
    ret=$($clixon_netconf -qf $cfg<<EOF
$DEFAULTHELLO
<rpc $DEFAULTNS>
  <process-control xmlns="http://clicon.org/lib">
    <name>restconf</name>
    <operation>status</operation>
  </process-control>
</rpc>]]>]]>
EOF
)
    # Check pid
    expect="<pid xmlns=\"http://clicon.org/lib\">[0-9]*</pid>"
    match=$(echo "$ret" | grep --null -Go "$expect")
    if [ -z "$match" ]; then
	pid=0
    else
	pid=$(echo "$match" | awk -F'[<>]' '{print $3}')
    fi
    if [ -z "$pid" ]; then
	err "No pid return value" "$ret"
    fi
    if $active; then
	expect="^<rpc-reply $DEFAULTNS><active $LIBNS>$active</active><description $LIBNS>Clixon RESTCONF process</description><command $LIBNS>/www-data/clixon_restconf -f $cfg -D [0-9]</command><status $LIBNS>$status</status><starttime $LIBNS>20[0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*Z</starttime><pid $LIBNS>$pid</pid></rpc-reply>]]>]]>$"
    else
	# inactive, no startime or pid
	expect="^<rpc-reply $DEFAULTNS><active $LIBNS>$active</active><description $LIBNS>Clixon RESTCONF process</description><command $LIBNS>/www-data/clixon_restconf -f $cfg -D [0-9]</command><status $LIBNS>$status</status></rpc-reply>]]>]]>$"
    fi
    match=$(echo "$ret" | grep --null -Go "$expect")
    if [ -z "$match" ]; then
	err "$expect" "$ret"
    fi
}

# FIRST usecase

new "1. Empty status message"

new "kill old restconf"
stop_restconf_pre

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

RESTCONFIG1=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <enable>true</enable>
   <debug>$RESTCONFDBG</debug>
</restconf>
EOF
)

new "1. get status"
rpcstatus false stopped
if [ $pid -ne 0 ]; then err "Pid" "$pid"; fi

new "enable minimal restconf, no server"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG1</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "commit minimal server"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "2. get status, get pid1"
rpcstatus true running
pid1=$pid
if [ $pid1 -eq 0 ]; then err "Pid" 0; fi

new "kill $pid1 externally"
sudo kill $pid1
sleep $DEMSLEEP

# Why kill it twice? it happens in docker somethimes but is not the aim of the test
new "kill $pid1 again"
sudo kill $pid1 2> /dev/null
sleep $DEMSLEEP

new "3. get status: Check killed"
rpcstatus false stopped
if [ $pid -ne 0 ]; then err "Pid" "$pid"; fi

RESTCONFIG2=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket>
</restconf>
EOF
)
new "create server"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG2</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "commit create server"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "4. get status"
rpcstatus true running
if [ $pid -eq 0 ]; then err "Pid" 0; fi

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

# SECOND usecase
new "2. zombie process on exit"

new "kill old restconf"
stop_restconf_pre

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

new "5. get status not started"
rpcstatus false stopped
if [ $pid -ne 0 ]; then err "Pid" "$pid"; fi

RESTCONFIG1=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <enable>true</enable>
   <debug>$RESTCONFDBG</debug>
   <auth-type>none</auth-type>
   <pretty>false</pretty>
   <socket><namespace>default</namespace><address>221.0.0.1</address><port>80</port><ssl>false</ssl></socket>
</restconf>
EOF
)

new "Create server with invalid address"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG1</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "commit invalid server"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

sleep $DEMSLEEP
new "Check zombies"
# NOTE unsure where zombies actually appear
ret=$(ps aux| grep clixon | grep defunc | grep -v grep)
if [ -n "$ret" ]; then
    err "No zombie process" "$ret"
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

sleep $DEMSLEEP
new "Check zombies again"
# NOTE unsure where zombies actually appear
ret=$(ps aux| grep clixon | grep defunc | grep -v grep)
if [ -n "$ret" ]; then
    err "No zombie process" "$ret"
fi

# THIRD usecase
# NOTE this does not apply for fcgi where servers cant be "removed"
if [ "${WITH_RESTCONF}" != "fcgi" ]; then
new "3. restconf not removed"

new "kill old restconf"
stop_restconf_pre

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

new "6. get status stopped"
rpcstatus false stopped
if [ $pid -ne 0 ]; then err "Pid" "$pid"; fi

RESTCONFIG1=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <enable>true</enable>
   <debug>$RESTCONFDBG</debug>
   <auth-type>none</auth-type>
   <pretty>false</pretty>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket>
</restconf>
EOF
)

new "Create server"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG1</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "commit create"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# pid
new "7. get status, get pid1"
rpcstatus true running
pid1=$pid
if [ $pid1 -eq 0 ]; then err "Pid" 0; fi
sleep $DEMSLEEP

new "Get restconf config 1"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/clixon-restconf:restconf)" 0 "HTTP/1.1 200 OK" "<restconf xmlns=\"http://clicon.org/restconf\"><enable>true</enable><auth-type>none</auth-type><debug>$RESTCONFDBG</debug><pretty>false</pretty><socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket></restconf>"

# remove it
new "Delete server"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS xmlns:nc=\"$BASENS\"><edit-config><target><candidate/></target><default-operation>none</default-operation><config><restconf xmlns=\"http://clicon.org/restconf\"><socket nc:operation=\"remove\"><namespace>default</namespace><address>0.0.0.0</address><port>80</port></socket></restconf></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS xmlns:nc=\"$BASENS\"><ok/></rpc-reply>]]>]]>$"

new "commit delete"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# Here restconf should have been restarted with no listener, the process is up but does not
# reply on restconf

new "8. get status, get different pid2"
rpcstatus true running
pid2=$pid
if [ $pid1 -eq 0 ]; then err "Pid" 0; fi

if [ $pid1 -eq $pid2 ]; then
    err1 "A different pid" "same pid: $pid1"
fi

new "Get restconf config 2: no server"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/clixon-restconf:restconf 2>&1)" 7 "Failed to connect" "Connection refused"

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

fi # "${WITH_RESTCONF}" != "fcgi"

new "endtest"
endtest

# Set by restconf_config
unset RESTCONFIG1
unset RESTCONFIG2
unset RESTCONFDBG
unset RCPROTO

rm -rf $dir

