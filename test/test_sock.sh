#!/usr/bin/env bash
# Simple Unix and IP internal socket tests
# See also test_nacm_credentials.sh for more advanced credential tests

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

#
# client <---> backend
#          ^ is unix, ipv4, ipv6 socket

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/socket.yang

# Set socket family and start backend and run a single cli command to
# check socket works
# 1: UNIX|IPv4|IPv6
# 2: unix file or ipv4 address or ipv6 address
# 3: sock port (if ipv4 or ipv6)
testrun(){
    family=$1
    sock=$2
    port=$3
    
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>*:*</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK_FAMILY>$family</CLICON_SOCK_FAMILY>
  <CLICON_SOCK_PORT>$port</CLICON_SOCK_PORT>
  <CLICON_SOCK>$sock</CLICON_SOCK>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

    new "test params: -f $cfg"
    if [ $BE -ne 0 ]; then
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s init -f $cfg"
	start_backend -s init -f $cfg
    fi

    new "$clixon_cli -1f $cfg show version"
    expectfn "$clixon_cli -1f $cfg show version" 0 "$version."

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
}

new "Unix socket"
testrun UNIX $dir/sock 0

new "IPv4 socket"
testrun IPv4 127.0.0.1 7878

#new "IPv6 socket" NYI
#testrun IPv6 ::1 7878

rm -rf $dir
