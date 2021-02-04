#!/usr/bin/env bash
# Netconf callhome RFC 8071

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Skip it no openssh
if ! [ -x "$(command -v ssh)" ]; then
    echo "...ssh not installed"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

: ${clixon_netconf_ssh_callhome:="clixon_netconf_ssh_callhome"}
: ${clixon_netconf_ssh_callhome_client:="clixon_netconf_ssh_callhome_client"}

APPNAME=example
cfg=$dir/conf_yang.xml
sshdcfg=$dir/sshd.conf
rpccmd=$dir/rpccmd.xml

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $rpccmd
<rpc $DEFAULTNS>
   <get-config>
      <source><candidate/></source>
   </get-config>
</rpc>]]>]]>
<rpc $DEFAULTNS>
   <close-session/>
</rpc>]]>]]>
EOF

# Make the callback after a sleep in separate thread simulating the server
# The result is not checked, only the client-side
function callhomefn()
{
    sleep 1

    new "Start Callhome in background"
    expectpart "$(sudo ${clixon_netconf_ssh_callhome} -a 127.0.0.1 -c $cfg)" 255 ""    
}

new "test params: -f $cfg"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg

    new "waiting"
    wait_backend
fi

# Start callhome server-side in background thread
callhomefn &

new "Start Listener client"
expectpart "$(ssh -s -v -o ProxyUseFdpass=yes -o ProxyCommand="${clixon_netconf_ssh_callhome_client} -a 127.0.0.1" . netconf < $rpccmd)" 0 "<hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:capability:yang-library:1.0?revision=2019-01-04&amp;module-set-id=42</capability><capability>urn:ietf:params:netconf:capability:candidate:1.0</capability><capability>urn:ietf:params:netconf:capability:validate:1.1</capability><capability>urn:ietf:params:netconf:capability:startup:1.0</capability><capability>urn:ietf:params:netconf:capability:xpath:1.0</capability><capability>urn:ietf:params:netconf:capability:notification:1.0</capability></capabilities><session-id>2</session-id></hello>]]>]]>" "<rpc-reply $DEFAULTNS><data/></rpc-reply>]]>]]>"

# Wait 
wait

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

new "Endtest"
endtest
rm -rf $dir
