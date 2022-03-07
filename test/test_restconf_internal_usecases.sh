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
# The fourth usecase is failing one of several sockets but still reach the working
#   1. Start two servers, where one fails
#   2. Reach one not the other
#   (Wanted to bind an invalid port, but then such a port must be bound and later killed)
# Note there are debug printfs marked as XXX for a race condition in travis

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Does not work with native http/2-only
if [ "${WITH_RESTCONF}" = "native" -a ${HAVE_HTTP1} = false ]; then
    echo "...skipped: Must run with http/1"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

APPNAME=example

cfg=$dir/conf.xml
startupdb=$dir/startup_db

# Restconf debug
RESTCONFDBG=$DBG
RCPROTO=http # no ssl here
HVER=1.1

INVALIDADDR=251.1.1.1 # used by fourth usecase as invalid

# log-destination in restconf xml: syslog or file
: ${LOGDST:=syslog}
# Set daemon command-line to -f
if [ "$LOGDST" = syslog ]; then
    LOGDST_CMD="s"      
elif [ "$LOGDST" = file ]; then
    LOGDST_CMD="f/var/log/clixon_restconf.log" 
else
    err1 "No such logdst: $LOGDST"
fi

if [ "${WITH_RESTCONF}" = "fcgi" ]; then
    EXTRACONF="<CLICON_FEATURE>clixon-restconf:fcgi</CLICON_FEATURE>"
else
    EXTRACONF=""
fi

cat <<EOF > $cfg
<clixon-config  $CONFNS>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  $EXTRACONF
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
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
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
  <CLICON_RESTCONF_INSTALLDIR>/usr/local/sbin</CLICON_RESTCONF_INSTALLDIR>
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
    retx=$($clixon_netconf -qf $cfg<<EOF
$DEFAULTHELLO
<rpc $DEFAULTNS>
  <process-control $LIBNS>
    <name>restconf</name>
    <operation>status</operation>
  </process-control>
</rpc>]]>]]>
EOF
)
    # Check pid
    expect="<pid $LIBNS>[0-9]*</pid>"
    match=$(echo "$retx" | grep --null -Go "$expect")
    if [ -z "$match" ]; then
	pid=0
    else
	pid=$(echo "$match" | awk -F'[<>]' '{print $3}')
    fi
    if [ -z "$pid" ]; then
	err "No pid return value" "$retx"
    fi

    if $active; then
	expect="^<rpc-reply $DEFAULTNS><active $LIBNS>$active</active><description $LIBNS>Clixon RESTCONF process</description><command $LIBNS>/.*/clixon_restconf -f $cfg -D [0-9] .*</command><status $LIBNS>$status</status><starttime $LIBNS>20[0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*Z</starttime><pid $LIBNS>$pid</pid></rpc-reply>]]>]]>$"
    else
	# inactive, no startime or pid
	expect="^<rpc-reply $DEFAULTNS><active $LIBNS>$active</active><description $LIBNS>Clixon RESTCONF process</description><command $LIBNS>/.*/clixon_restconf -f $cfg -D [0-9] .*</command><status $LIBNS>$status</status></rpc-reply>]]>]]>$"
    fi
    match=$(echo "$retx" | grep --null -Go "$expect")
    if [ -z "$match" ]; then
	err "$expect" "$retx"
    fi
}

# FIRST usecase

new "FIRST usecase: Empty status message"

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

new "Check $pid1 exists"
# Here backend dies / is killed
# if sudo kill -0 $pid1; then # XXX 
while sudo kill -0 $pid1 2> /dev/null; do
    new "kill $pid1 externally"
    sudo kill $pid1
    sleep 1 # There is a race condition here when restconf is killed while waiting for reply from backend
done
# fi

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
new "SECOND usecase: zombie process on exit"

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
   <log-destination>$LOGDST</log-destination>
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
retx=$(ps aux| grep clixon | grep defunc | grep -v grep)
if [ -n "$retx" ]; then
    err "No zombie process" "$retx"
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
retx=$(ps aux| grep clixon | grep defunc | grep -v grep)
if [ -n "$retx" ]; then
    err "No zombie process" "$retx"
fi

# THIRD usecase
# NOTE this does not apply for fcgi where servers cant be "removed"
if [ "${WITH_RESTCONF}" != "fcgi" ]; then
new "THIRD usecase: restconf not removed"

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
   <log-destination>$LOGDST</log-destination>
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

new "wait restconf"
wait_restconf

# pid
new "7. get status, get pid1"
rpcstatus true running
pid1=$pid
if [ $pid1 -eq 0 ]; then err "Pid" 0; fi
sleep $DEMSLEEP

new "Get restconf config 1"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/clixon-restconf:restconf)" 0 "HTTP/$HVER 200" "<restconf xmlns=\"http://clicon.org/restconf\"><enable>true</enable><auth-type>none</auth-type><debug>$RESTCONFDBG</debug><log-destination>$LOGDST</log-destination><enable-core-dump>false</enable-core-dump><pretty>false</pretty><socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket></restconf>"

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
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/clixon-restconf:restconf 2>&1)" 7 # curl 7.58: "Failed to connect" "Connection refused", curl 7.74: "Couldn't connect to server"

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

# FOURTH usecase

if [ "${WITH_RESTCONF}" != "fcgi" ]; then
# Does not apply for fcgi where servers are configured in nginx

new "FOURTH usecase. One server fails, others working"

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

new "9. get status stopped"
rpcstatus false stopped
if [ $pid -ne 0 ]; then err "Pid" "$pid"; fi

RESTCONFIG1=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <enable>true</enable>
   <debug>$RESTCONFDBG</debug>
   <log-destination>$LOGDST</log-destination>
   <auth-type>none</auth-type>
   <pretty>false</pretty>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket>
   <socket><namespace>default</namespace><address>$INVALIDADDR</address><port>8080</port><ssl>false</ssl></socket>
</restconf>
EOF
)

new "Create server"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG1</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "commit create"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "wait restconf"
wait_restconf

# pid
new "10. get status, get pid1"
rpcstatus true running
pid1=$pid
if [ $pid1 -eq 0 ]; then err "Pid" 0; fi
sleep $DEMSLEEP

new "Get restconf config"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/clixon-restconf:restconf)" 0 "HTTP/$HVER 200" "<restconf xmlns=\"http://clicon.org/restconf\"><enable>true</enable><auth-type>none</auth-type><debug>$RESTCONFDBG</debug><log-destination>$LOGDST</log-destination><enable-core-dump>false</enable-core-dump><pretty>false</pretty><socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket><socket><namespace>default</namespace><address>$INVALIDADDR</address><port>8080</port><ssl>false</ssl></socket></restconf>"

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

new "kill restconf"
stop_restconf

new "endtest"
endtest

# Set by restconf_config
unset LOGDST
unset LOGDST_CMD
unset RESTCONFIG1
unset RESTCONFIG2
unset RESTCONFDBG
unset RCPROTO
unset HVER

rm -rf $dir

