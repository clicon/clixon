#!/usr/bin/env bash
# Restconf direct start/stop using RPC and config enable flag (as alternative to systemd or other)
# According to the following behaviour:
# - on RPC start, if enable is true, start the service, if false, error or ignore it
# - on RPC stop, stop the service 
# - on backend start make the state as configured
# - on enable change, make the state as configured
# - No restconf config means enable: false (extra rule)
# See test_restconf_netns for network namespaces
# See test_restconf_internal_cases for some special use-cases
# XXX Lots of sleeps to remove race conditions. I am sure there are others way to fix this
# Note you cant rely on ps aux|grep <cmd> since ps delays after fork from clixon_backend->restconf

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
<clixon-config $CONFNS>
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
function rpcstatus()
{
    if [ $# -ne 2 ]; then
	err1 "rpcstatus: # arguments: 2" "$#"
    fi
    active=$1
    status=$2
    
    sleep $DEMSLEEP
    new "send rpc status"
    rpc=$(chunked_framing "<rpc $DEFAULTNS><process-control $LIBNS><name>restconf</name><operation>status</operation></process-control></rpc>")
    retx=$($clixon_netconf -qef $cfg<<EOF
$DEFAULTHELLO$rpc
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
	expect="^<rpc-reply $DEFAULTNS><active $LIBNS>$active</active><description $LIBNS>Clixon RESTCONF process</description><command $LIBNS>/.*/clixon_restconf -f $cfg -D [0-9] .*</command><status $LIBNS>$status</status><starttime $LIBNS>20[0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*Z</starttime><pid $LIBNS>$pid</pid></rpc-reply>$"
    else
	# inactive, no startime or pid
	expect="^<rpc-reply $DEFAULTNS><active $LIBNS>$active</active><description $LIBNS>Clixon RESTCONF process</description><command $LIBNS>/.*/clixon_restconf -f $cfg -D [0-9] .*</command><status $LIBNS>$status</status></rpc-reply>$"
    fi

    match=$(echo "$retx" | grep --null -Go "$expect")
    if [ -z "$match" ]; then
	err "$expect" "$retx"
    fi
}

# Subroutine send a process control RPC and tricks to echo process-id returned
# Args:
# 1: operation   One of stop/start/restart
function rpcoperation()
{
    operation=$1
    
    sleep $DEMSLEEP
    new "send rpc $operation"
    expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><process-control $LIBNS><name>restconf</name><operation>$operation</operation></process-control></rpc>" "" "<rpc-reply $DEFAULTNS><ok $LIBNS/></rpc-reply>"

    sleep $DEMSLEEP
}

# This test is confusing:
# The whole restconf config is in clixon-config which binds 0.0.0.0:80 which will be the only
# config the restconf daemon ever reads.
# However, enable (and debug) flag is stored in running db but only backend will ever read that.
# It just controls how restconf is started, but thereafter the restconf daemon reads the static db in clixon-config file

new "ENABLE true"
# First basic operation with restconf enable is true
cat<<EOF > $startupdb
<${DATASTORE_TOP}>
   <restconf xmlns="http://clicon.org/restconf">
      <enable>true</enable>
      <auth-type>none</auth-type>
      <pretty>false</pretty>
      <debug>$RESTCONFDBG</debug>
      <log-destination>$LOGDST</log-destination>
      <socket>
         <namespace>default</namespace>
	 <address>0.0.0.0</address>
	 <port>80</port>
	 <ssl>false</ssl>
      </socket>
   </restconf>
</${DATASTORE_TOP}>
EOF

new "kill old restconf"
stop_restconf_pre

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

# For debug
#>&2 echo "curl $CURLOPTS -X POST -H \"Content-Type: application/yang-data+json\" $RCPROTO://localhost/restconf/operations/clixon-lib:process-control -d '{\"clixon-lib:input\":{\"name\":\"restconf\",\"operation\":\"status\"}}'"

# Get pid of running process and check return xml
new "1. Get rpc status"
rpcstatus true running 

pid0=$pid # Save pid0
if [ $pid0 -eq 0 ]; then err "Pid" 0; fi

# pid0 is active but doesnt mean socket is open, wait for that
new "Wait for restconf to start"
wait_restconf

new "check restconf process runnng using ps pid:$pid0"
ps=$(ps -hp $pid0) 

if [ -z "$ps" ]; then
    err "Restconf $pid0 not found"
fi

new "check parent process of pid:$pid0"
ppid=$(ps -o ppid= -p $pid0)
if [ "$ppid" -eq 1 -o "$ppid" -eq "$pid0" ]; then
    err "Restconf parent pid of $pid0 is $ppid is wrong"
fi

new "wait restconf"
wait_restconf

new "try restconf rpc status"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/operations/clixon-lib:process-control -d '{"clixon-lib:input":{"name":"restconf","operation":"status"}}')" 0 "HTTP/$HVER 200" '{"clixon-lib:output":' '"active":' '"pid":'

# debug setting clutters screen
#new "Set backend debug using restconf"
#expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/operations/clixon-lib:debug -d '{"clixon-lib:input":{"level":1}}')" 0 "HTTP/$HVER 204"

new "Set restconf debug using netconf"
#expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><restconf $RESTCONFNS><debug>1</debug></restconf></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "2. Get status"
rpcstatus true running
pid1=$pid
if [ $pid1 -eq 0 ]; then err "pid" 0; fi

new "Check same pid"
if [ "$pid0" -ne "$pid1" ]; then
    err "$pid0" "$pid1"
fi

new "try restconf rpc restart"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/operations/clixon-lib:process-control -d '{"clixon-lib:input":{"name":"restconf","operation":"restart"}}')" 0 "HTTP/$HVER 204"

new "3. Get status"
rpcstatus true running
pid1=$pid
if [ $pid1 -eq 0 ]; then err "Pid" 0; fi

new "check different pids"
if [ "$pid0" -eq "$pid1" ]; then
    err1 "not $pid0" "$pid1"
fi

# This is to avoid a race condition: $pid1 is starting and may not have come up yet when we
# we later stop it.
new "Wait for $pid1 to start"
wait_restconf

new "4. stop restconf RPC"
rpcoperation stop
if [ $? -ne 0 ]; then exit -1; fi

new "Wait for restconf to stop"
wait_restconf_stopped

new "5. Get rpc status stopped"
rpcstatus false stopped
if [ $pid -ne 0 ]; then err "Pid" "$pid"; fi

new "6. Start rpc again"
rpcoperation start
if [ $? -ne 0 ]; then exit -1; fi

new "7. Get rpc status"
rpcstatus true running
pid3=$pid
if [ $pid3 -eq 0 ]; then err "Pid" 0; fi

new "check restconf process running using ps"
ps=$(ps -hp $pid3)
if [ -z "$ps" ]; then
    err "A restconf running"
fi

if [ $pid0 -eq $pid3 ]; then
    err1 "A different pid" "same pid: $pid3"
fi

new "kill restconf"
sudo kill $pid3

new "Wait for restconf to stop"
wait_restconf_stopped

new "8. start restconf RPC"
rpcoperation start
if [ $? -ne 0 ]; then exit -1; fi

new "9. check status RPC on"
rpcstatus true running
pid5=$pid
if [ $pid5 -eq 0 ]; then err "Pid" 0; fi

new "10. restart restconf RPC"
rpcoperation restart
if [ $? -ne 0 ]; then exit -1; fi

new "11. Get restconf status rpc"
rpcstatus true running
pid7=$pid
if [ $pid7 -eq 0 ]; then err "Pid" 0; fi

if [ $pid5 -eq $pid7 ]; then
    err1 "A different pid" "samepid: $pid7"
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

# Restconf is enabled and restconf was running but was killed by stop ^.
# Start backend with -s none should start restconf too via ca_reset rule

new "Restart backend -s none"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s none -f $cfg"
    start_backend -s none -f $cfg
fi

new "wait backend"
wait_backend
    
new "wait restconf"
wait_restconf

if  [ $valgrindtest -ne 2 ]; then # Restart with same restconf pid does not work w backend valgrind test
    new "12. Get restconf (running) after restart"
    rpcstatus true running
    if [ $pid -eq 0 ]; then err "Pid" 0; fi
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
#--------------------------

# Now start with enable=false

new "enable false"
# Second basic operation with restconf enable is false
cat<<EOF > $startupdb
<${DATASTORE_TOP}>
   <restconf xmlns="http://clicon.org/restconf">
      <enable>false</enable>
      <auth-type>none</auth-type>
      <pretty>false</pretty>
      <debug>$RESTCONFDBG</debug>
      <log-destination>$LOGDST</log-destination>
      <socket>
         <namespace>default</namespace>
	 <address>0.0.0.0</address>
	 <port>80</port>
	 <ssl>false</ssl>
      </socket>
   </restconf>
</${DATASTORE_TOP}>
EOF

new "kill old restconf"
sleep $DEMSLEEP
stop_restconf_pre

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

new "13. check status RPC off"
rpcstatus false stopped
if [ $pid -ne 0 ]; then err "Pid" "$pid"; fi

new "14. start restconf RPC (but disabled)"
rpcoperation start
if [ $? -ne 0 ]; then exit -1; fi

new "15. check status RPC still off"
rpcstatus false stopped
if [ $pid -ne 0 ]; then err "Pid" "$pid"; fi

new "Enable restconf"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><restconf xmlns=\"http://clicon.org/restconf\"><enable>true</enable><debug>$RESTCONFDBG</debug><log-destination>$LOGDST</log-destination></restconf></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit enable"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "16. check status RPC on"
rpcstatus true running
pid1=$pid
if [ $pid1 -eq 0 ]; then err "Pid" 0; fi

new "wait restconf"
wait_restconf

# Edit a field, eg pretty to trigger a restart
new "Edit a restconf field via restconf" # XXX fcgi fails here
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/clixon-restconf:restconf/pretty -d '{"clixon-restconf:pretty":true}' )" 0 "HTTP/$HVER 204"

sleep $DEMSLEEP

new "check status RPC new pid"
rpcstatus true running
pid2=$pid
if [ $pid2 -eq 0 ]; then err "Pid" 0; fi

if [ $pid1 -eq $pid2 ]; then
    err1 "A different pid" "$pid1"
fi

new "wait restconf"
wait_restconf

new "Edit a non-restconf field via restconf"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data -d '{"example:val":"xyz"}' )" 0 "HTTP/$HVER 201"

new "17. check status RPC same pid"
rpcstatus true running
pid3=$pid
if [ $pid3 -eq 0 ]; then err "Pid" 0; fi

if [ $pid2 -ne $pid3 ]; then
    err1 "Same pid $pid2" "$pid3"
fi

new "Disable restconf"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><restconf xmlns=\"http://clicon.org/restconf\"><enable>false</enable></restconf></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit disable"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

sleep $DEMSLEEP

new "18. check status RPC off"
rpcstatus false stopped
if [ $pid -ne 0 ]; then err "Pid" "$pid"; fi

# Negative validation checks of clixon-restconf / socket

new "netconf edit config invalid ssl"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><restconf xmlns=\"http://clicon.org/restconf\" nc:operation=\"replace\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><enable>true</enable><socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>true</ssl></socket></restconf></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate should fail"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>SSL enabled but server-cert-path not set</error-message></rpc-error></rpc-reply>"

# stop backend
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

#Start backend -s none should start 

new "kill restconf"
sleep $DEMSLEEP
stop_restconf

new "endtest"
endtest

# Set by restconf_config
unset HVER
unset LOGDST
unset LOGDST_CMD
unset pid
unset RESTCONFIG
unset RESTCONFDBG
unset RCPROTO
unset retx

rm -rf $dir
