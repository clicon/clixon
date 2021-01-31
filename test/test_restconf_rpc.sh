#!/usr/bin/env bash
# Restconf direct start/stop using RPC and config enable flag (as alternative to systemd or other)
# According tot he following behaviour:
# - on RPC start, if enable is true, start the service, if false, error or ignore it
# - on RPC stop, stop the service 
# - on backend start make the state as configured
# - on enable change, make the state as configured
# - No restconf config means enable: false (extra rule)
# See test_restconf_netns for network namespaces

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
startupdb=$dir/startup_db

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
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
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

# Subroutine send a process control RPC and tricks to echo process-id returned
# Args:
# 1: operation
# 2: expectret  0: means expect pi 0 as return, else something else
testrpc()
{
    operation=$1
    expectret=$2
    
    new "send rpc $operation"
    ret=$($clixon_netconf -qf $cfg<<EOF
<rpc $DEFAULTNS>
  <process-control xmlns="http://clicon.org/lib">
    <name>restconf</name>
    <operation>$operation</operation>
  </process-control>
</rpc>]]>]]>
EOF
)

    expect1="<rpc-reply $DEFAULTNS><pid xmlns=\"http://clicon.org/lib\">"
    match=$(echo "$ret" | grep --null -Go "$expect1")
    if [ -z "$match" ]; then
	err "$expect1" "$ret"
    fi

#    >&2 echo "ret:$ret" # debug
    
    expect2="</pid></rpc-reply>]]>]]>"
    match=$(echo "$ret" | grep --null -Go "$expect2")
    if [ -z "$match" ]; then
	err "$expect2" "$ret"
    fi
    new "check rpc $operation get pid"
    pid=$(echo "$ret" | awk -F'[<>]' '{print $5}')
    >&2 echo "pid:$pid" # debug
    if [ -z "$pid" ]; then
	err "Running process" "$ret"
    fi
    new "check restconf retvalue"
    if [ $expectret -eq 0 ]; then
	if [ $pid -ne 0 ]; then
	    err "No process" "$pid"
	fi
    else
	if [ $pid -eq 0 ]; then
	    err "Running process"
	fi
    fi


    echo $pid # cant use return that only uses 0-255
}

new "ENABLE true"
# First basic operation with restconf enable is true
cat<<EOF > $startupdb
<config>
   <restconf xmlns="http://clicon.org/restconf">
      <enable>true</enable>
   </restconf>
</config>
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

# Get pid of running process and check return xml
new "Get rpc status"
pid0=$(testrpc status 1) # Save pid0
if [ $? -ne 0 ]; then echo "$pid0";exit -1; fi

new "check restconf process running using ps pid0:$pid0"
ps=$(ps -hp $pid0) 

if [ -z "$ps" ]; then
    err "A restconf running"
fi

new "stop restconf RPC"
pid=$(testrpc stop 0)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "Get rpc status stopped"
pid=$(testrpc status 0)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "Start rpc again"
pid3=$(testrpc start 1) # Save pid3
if [ $? -ne 0 ]; then echo "$pid3";exit -1; fi

new "check restconf process running using ps"
ps=$(ps -hp $pid3)
if [ -z "$ps" ]; then
    err "A restconf running"
fi

if [ $pid0 -eq $pid3 ]; then
    err "A different pid" "$pid3"
fi

new "kill restconf"
stop_restconf_pre

new "start restconf RPC"
pid=$(testrpc start 1)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "check status RPC on"
pid5=$(testrpc status 1) # Save pid5
if [ $? -ne 0 ]; then echo "$pid5";exit -1; fi

new "restart restconf RPC"
pid=$(testrpc restart 1)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "Get restconf status rpc"
pid7=$(testrpc status 1) # Save pid7
if [ $? -ne 0 ]; then echo "$pid7";exit -1; fi

if [ $pid5 -eq $pid7 ]; then
    err "A different pid" "$pid7"
fi

#if [ $valgrindtest -eq 0 ]; then # Cant get pgrep to work properly
#    new "check new pid"
#    sleep $DEMWAIT # Slows the tests down considerably, but needed in eg docker test
#    pid1=$(pgrep clixon_restconf)
#    if [ -z "$pid0" -o -z "$pid1" ]; then
#        err "Pids expected" "pid0:$pid0 = pid1:$pid1"
#    fi
#    if [ $pid0 -eq $pid1 ]; then#
#	err "Different pids" "pid0:$pid0 = pid1:$pid1"
#    fi
#fi

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

new "Get restconf (running) after restart"
pid=$(testrpc status 1)
if [ $? -ne 0 ]; then echo "$pid"; exit -1; fi

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
<config>
   <restconf xmlns="http://clicon.org/restconf">
      <enable>false</enable>
   </restconf>
</config>
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

new "check status RPC off"
pid=$(testrpc status 0)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "start restconf RPC"
pid=$(testrpc start 0)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "check status RPC off"
pid=$(testrpc status 0)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "Enable restconf"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><restconf xmlns=\"http://clicon.org/restconf\"><enable>true</enable></restconf></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "check status RPC on"
pid=$(testrpc status 1)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

new "Disable restconf"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><restconf xmlns=\"http://clicon.org/restconf\"><enable>false</enable></restconf></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "check status RPC off"
pid=$(testrpc status 0)
if [ $? -ne 0 ]; then echo "$pid";exit -1; fi

# Negative validation checks of clixon-restconf / socket

new "netconf edit config invalid ssl"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><restconf xmlns=\"http://clicon.org/restconf\" nc:operation=\"replace\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><enable>true</enable><socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>true</ssl></socket></restconf></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>SSL enabled but server-cert-path not set</error-message></rpc-error></rpc-reply>]]>]]>$"

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
sleep $DEMWAIT # Lots of processes need to die before next test

new "endtest"
endtest

rm -rf $dir

