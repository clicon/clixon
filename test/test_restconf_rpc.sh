#!/usr/bin/env bash
# Restconf direct start/stop using RPC and config enable flag (as alternative to systemd or other)
# According to the following behaviour:
# - on RPC start, if enable is true, start the service, if false, error or ignore it
# - on RPC stop, stop the service 
# - on backend start make the state as configured
# - on enable change, make the state as configured
# - No restconf config means enable: false (extra rule)
# See test_restconf_netns for network namespaces
# XXX Lots of sleeps to remove race conditions. I am sure there are others way to fix this

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
startupdb=$dir/startup_db

# Define default restconfig config: RESTCONFIG
restconf_config none false

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
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
  $RESTCONFIG
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
# Args:
# 1: operation
# 2: expectret  0: means expect pi 0 as return, else something else
function testrpc()
{
    operation=$1
    expectret=$2
    
    sleep $DEMSLEEP
    new "send rpc $operation"
    ret=$($clixon_netconf -qf $cfg<<EOF
$DEFAULTHELLO
<rpc $DEFAULTNS>
  <process-control xmlns="http://clicon.org/lib">
    <name>restconf</name>
    <operation>$operation</operation>
  </process-control>
</rpc>]]>]]>
EOF
)

#    >&2 echo "ret:$ret" # debug

    expect1="<pid xmlns=\"http://clicon.org/lib\">[0-9]*</pid>"
    match=$(echo "$ret" | grep --null -Go "$expect1")
#    >&2 echo "match:$match" # debug
    if [ -z "$match" ]; then
	pid=0
    else
	pid=$(echo "$match" | awk -F'[<>]' '{print $3}')
    fi
    >&2 echo "pid:$pid" # debug

    if [ -z "$pid" ]; then
	err "Running process" "$ret"
    fi

    new "check restconf retvalue"
    if [ $operation = "status" ]; then
	if [ $expectret -eq 0 ]; then
	    if [ $pid -ne 0 ]; then
		err "No process" "$pid"
	    fi
	else
	    if [ $pid -eq 0 ]; then
		err "Running process"
	    fi
	fi
	echo "$pid" # cant use return that only uses 0-255
    fi
    sleep $DEMSLEEP
}

new "ENABLE true"
# First basic operation with restconf enable is true
cat<<EOF > $startupdb
<${DATASTORE_TOP}>
   <restconf xmlns="http://clicon.org/restconf">
      <enable>true</enable>
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

    new "wait backend"
    wait_backend
fi

# For debug
#>&2 echo "curl $CURLOPTS -X POST -H \"Content-Type: application/yang-data+json\" $RCPROTO://localhost/restconf/operations/clixon-lib:process-control -d '{\"clixon-lib:input\":{\"name\":\"restconf\",\"operation\":\"status\"}}'"

# Get pid of running process and check return xml
new "1. Get rpc status"
pid0=$(testrpc status 1) # Save pid0
if [ $? -ne 0 ]; then echo "$pid0";exit -1; fi

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
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/operations/clixon-lib:process-control -d '{"clixon-lib:input":{"name":"restconf","operation":"status"}}')" 0 "HTTP/1.1 200 OK" '{"clixon-lib:output":' '"active":' '"pid":'

new "2. Get status"
pid1=$(testrpc status 1)
if [ $? -ne 0 ]; then echo "$pid1";exit -1; fi

new "Check same pid"
if [ "$pid0" -ne "$pid1" ]; then
    err "$pid0" "$pid1"
fi

new "try restconf rpc restart"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/operations/clixon-lib:process-control -d '{"clixon-lib:input":{"name":"restconf","operation":"restart"}}')" 0 "HTTP/1.1 204 No Content"

new "3. Get status"
pid1=$(testrpc status 1)
if [ $? -ne 0 ]; then echo "$pid1";exit -1; fi

new "check different pids"
if [ "$pid0" -eq "$pid1" ]; then
    err "not $pid0"
fi

new "4. stop restconf RPC"
testrpc stop 0
if [ $? -ne 0 ]; then exit -1; fi

new "5. Get rpc status stopped"
pid=$(testrpc status 0)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "6. Start rpc again"
testrpc start 0
if [ $? -ne 0 ]; then exit -1; fi

new "7. Get rpc status"
pid3=$(testrpc status 1)
if [ $? -ne 0 ]; then echo "$pid3";exit -1; fi

new "check restconf process running using ps"
ps=$(ps -hp $pid3)
if [ -z "$ps" ]; then
    err "A restconf running"
fi

if [ $pid0 -eq $pid3 ]; then
    err "A different pid" "same pid: $pid3"
fi

new "kill restconf"
stop_restconf_pre

new "8. start restconf RPC"
testrpc start 0
if [ $? -ne 0 ]; then exit -1; fi

new "9. check status RPC on"
pid5=$(testrpc status 1) # Save pid5
if [ $? -ne 0 ]; then echo "$pid5";exit -1; fi

new "10. restart restconf RPC"
testrpc restart 0
if [ $? -ne 0 ]; then exit -1; fi

new "11. Get restconf status rpc"
pid7=$(testrpc status 1) # Save pid7
if [ $? -ne 0 ]; then echo "$pid7";exit -1; fi

if [ $pid5 -eq $pid7 ]; then
    err "A different pid" "samepid: $pid7"
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

    new "waiting"
    wait_backend
fi

new "12. Get restconf (running) after restart"
pid=$(testrpc status 1)
if  [ valgrindtest -ne 2 ]; then # XXX does not work w backend valgrind test
    if [ $? -ne 0 ]; then echo "$pid"; exit -1; fi
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

# So far, restconf config enable flag has been true. Now change enable flag.

new "ENABLE false"
# Second basic operation with restconf enable is false
cat<<EOF > $startupdb
<${DATASTORE_TOP}>
   <restconf xmlns="http://clicon.org/restconf">
      <enable>false</enable>
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

    new "waiting"
    wait_backend
fi

new "13. check status RPC off"
pid=$(testrpc status 0)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "14. start restconf RPC"
testrpc start 0
if [ $? -ne 0 ]; then exit -1; fi

new "15. check status RPC off"
pid=$(testrpc status 0)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "Enable restconf"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><restconf xmlns=\"http://clicon.org/restconf\"><enable>true</enable></restconf></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

sleep $DEMSLEEP

new "16. check status RPC on"
pid=$(testrpc status 1)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

# Edit a field, eg debug
new "Edit a restconf field via restconf"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/clixon-restconf:restconf/debug -d '{"clixon-restconf:debug":1}' )" 0 "HTTP/1.1 201 Created"

new "check status RPC new pid"
pid1=$(testrpc status 1)

if [ $? -ne 0 ]; then echo "$pid1";exit -1; fi
if [ $pid -eq $pid1 ]; then
    err "A different pid" "Same pid: $pid"
fi

sleep $DEMSLEEP

new "Edit a non-restconf field via restconf"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data -d '{"example:val":"xyz"}' )" 0 "HTTP/1.1 201 Created"

new "check status RPC same pid"
pid2=$(testrpc status 1)
if [ $? -ne 0 ]; then echo "$pid2";exit -1; fi
if [ $pid1 -ne $pid2 ]; then
    err "Same pid $pid1" "$pid2"
fi

new "Disable restconf"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><restconf xmlns=\"http://clicon.org/restconf\"><enable>false</enable></restconf></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "17. check status RPC off"
pid=$(testrpc status 0)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

# Negative validation checks of clixon-restconf / socket

new "netconf edit config invalid ssl"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><restconf xmlns=\"http://clicon.org/restconf\" nc:operation=\"replace\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><enable>true</enable><socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>true</ssl></socket></restconf></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>SSL enabled but server-cert-path not set</error-message></rpc-error></rpc-reply>]]>]]>$"

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

unset pid
sleep $DEMSLEEP # Lots of processes need to die before next test

new "endtest"
endtest

# Set by restconf_config
unset RESTCONFIG

rm -rf $dir

