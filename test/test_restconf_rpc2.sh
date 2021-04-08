#!/usr/bin/env bash
# Send restconf rpc:s when starting from backend
# Two specific usecases that have been problematic are tested here
# In comparison test_restconf_rpc.sh:
# - uses externally started restconf, here started by backend
# - generic tests, here specific
# The first usecases is:
#   1. Start a minimal restconf
#   2. Kill it externally (or it exits)
#   3. Start a server
#   4. Query status (Error message is returned)
# The second usecase is
#   1. Start server with bad address
#   2. Zombie process appears

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
startupdb=$dir/startup_db

# Restconf debug
RESTCONFDBG=0

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
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

    >&2 echo "ret:$ret" # debug

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

LIBNS='xmlns="http://clicon.org/lib"'

new "get status 1"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><process-control xmlns=\"http://clicon.org/lib\"><name>restconf</name><operation>status</operation></process-control></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><active $LIBNS>false</active><description $LIBNS>Clixon RESTCONF process</description><command $LIBNS>/www-data/clixon_restconf -f $cfg -D $RESTCONFDBG</command></rpc-reply>]]>]]>$"

new "enable minimal restconf, no server"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG1</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# Get pid2
pid2=$(testrpc status 1)
echo "pid:$pid2"

new "get status 2"
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
expect="^<rpc-reply $DEFAULTNS><active $LIBNS>true</active><description $LIBNS>Clixon RESTCONF process</description><pid $LIBNS>$pid2</pid><command $LIBNS>/www-data/clixon_restconf -f $cfg -D $RESTCONFDBG</command><starttime $LIBNS>20[0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*Z</starttime>"
match=$(echo "$ret" | grep --null -Go "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

# Kill it
sudo kill $pid2
sleep $DEMSLEEP

# Ensure no pid
pid2=$(testrpc status 0)

RESTCONFIG2=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket>
</restconf>
EOF
)
new "create a server"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG2</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# 3. get status

new "get status 3"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><process-control xmlns=\"http://clicon.org/lib\"><name>restconf</name><operation>status</operation></process-control></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><active $LIBNS>true</active><description $LIBNS>Clixon RESTCONF process</description><pid $LIBNS>"

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

sleep $DEMSLEEP # Lots of processes need to die before next test

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

new "get status 1"
testrpc status 0

RESTCONFIG1=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <enable>true</enable>
   <debug>$RESTCONFDBG</debug>
   <auth-type>none</auth-type>
   <server-cert-path>$srvcert</server-cert-path>
   <server-key-path>$srvkey</server-key-path>
   <server-ca-cert-path>$cakey</server-ca-cert-path>
   <pretty>false</pretty>
   <socket><namespace>default</namespace><address>221.0.0.1</address><port>80</port><ssl>false</ssl></socket>
</restconf>
EOF
)

new "Create server with invalid address"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG1</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

sleep $DEMSLEEP
new "Check zombies"
ret=$(ps aux|grep defunc | grep -v grep)
if [ -n "$ret" ]; then
    err "No zombie process" "$ret"
fi

new "endtest"
endtest

# Set by restconf_config
unset RESTCONFIG1
unset RESTCONFIG2
unset RESTCONFDBG

rm -rf $dir

