#!/usr/bin/env bash
# Restconf basic functionality also uri encoding using eth/0/0
# Note there are many variants: (1)fcgi/native, (2) http/https, (3) IPv4/IPv6, (4)local or backend-config
# (1) fcgi/native
# This is compile-time --with-restconf=fcgi or native, so either or
# - fcgi: Assume http server setup, such as nginx described in apps/restconf/README.md
# - native: test both local config and get config from backend 
# (2) http/https
# - fcgi: relies on nginx has https setup
# - native: generate self-signed server certs 
# (3) IPv4/IPv6 (only loopback 127.0.0.1 / ::1)
# - The tests runs through both
# - IPv6 by default disabled since docker does not support it out-of-the box
# (4) local/backend config. Native only
# - The tests runs through both (if compiled with native)
# See also test_restconf_op.sh
# See test_restconf_rpc.sh for cases when CLICON_BACKEND_RESTCONF_PROCESS is set

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Only works with native and https
if [ "${WITH_RESTCONF}" != "native" ]; then
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

RCPROTO=https
APPNAME=example

cfg=$dir/conf.xml

# If nmap not installed just quietly quit
if [ ! -n "$(type nmap 2> /dev/null)" ]; then
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

# clixon-example and clixon-restconf is used in the test, need local copy
# This is a kludge: look in src otherwise assume it is installed in /usr/local/share
# Note that revisions may change and may need to be updated
y="clixon-example@${CLIXON_EXAMPLE_REV}.yang"

if [ -d ${TOP_SRCDIR}/example/main/$y ]; then 
    cp ${TOP_SRCDIR}/example/main/$y $dir/
else
    cp /usr/local/share/clixon/$y $dir/
fi
y=clixon-restconf@${CLIXON_RESTCONF_REV}.yang
if [ -d ${TOP_SRCDIR}/yang/clixon ]; then 
    cp ${TOP_SRCDIR}/yang/clixon/$y $dir/
else
    cp /usr/local/share/clixon/$y $dir/
fi

if [ "${WITH_RESTCONF}" = "native" ]; then
    # Create server certs
    certdir=$dir/certs
    srvkey=$certdir/srv_key.pem
    srvcert=$certdir/srv_cert.pem
    cakey=$certdir/ca_key.pem # needed?
    cacert=$certdir/ca_cert.pem
    test -d $certdir || mkdir $certdir
    # Create server certs and CA
    cacerts $cakey $cacert
    servercerts $cakey $cacert $srvkey $srvcert
    USEBACKEND=true
else
    # Define default restconfig config: RESTCONFIG
    RESTCONFIG=$(restconf_config none false)
    USEBACKEND=false
fi

# This is a fixed 'state' implemented in routing_backend. It is assumed to be always there
state='{"clixon-example:state":{"op":\["41","42","43"\]}'

if $IPv6; then
    # For backend config, create 4 sockets, all combinations IPv4/IPv6 + http/https
    RESTCONFIG1=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <enable>true</enable>
   <auth-type>none</auth-type>
   <server-cert-path>$srvcert</server-cert-path>
   <server-key-path>$srvkey</server-key-path>
   <server-ca-cert-path>$cakey</server-ca-cert-path>
   <pretty>false</pretty>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>443</port><ssl>true</ssl></socket>
   <socket><namespace>default</namespace><address>::</address><port>80</port><ssl>false</ssl></socket>
   <socket><namespace>default</namespace><address>::</address><port>443</port><ssl>true</ssl></socket>
</restconf>
EOF
)
else
       # For backend config, create 2 sockets, all combinations IPv4 + http/https
    RESTCONFIG1=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <enable>true</enable>
   <auth-type>none</auth-type>
   <server-cert-path>$srvcert</server-cert-path>
   <server-key-path>$srvkey</server-key-path>
   <server-ca-cert-path>$cakey</server-ca-cert-path>
   <pretty>false</pretty>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>443</port><ssl>true</ssl></socket>
</restconf>
EOF
)
fi

# Clixon config
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
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
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_BACKEND_RESTCONF_PROCESS>$USEBACKEND</CLICON_BACKEND_RESTCONF_PROCESS>
  $RESTCONFIG <!-- only fcgi -->
</clixon-config>
EOF

new "test params: -f $cfg -- -s"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure
    
    new "start backend -s init -f $cfg -- -s"
    start_backend -s init -f $cfg -- -s
fi

new "wait backend"
wait_backend

new "netconf edit config"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG1</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre
    
    new "start restconf daemon"
    # inline of start_restconf, cant make quotes to work
    echo "sudo -u $wwwstartuser -s $clixon_restconf $RCLOG -D $DBG -f $cfg -R <xml>"
    sudo -u $wwwstartuser -s $clixon_restconf $RCLOG -D $DBG -f $cfg -R "$RESTCONFIG1" &
    if [ $? -ne 0 ]; then
	err1 "expected 0" "$?"
    fi
fi

new "wait restconf"
wait_restconf

sleep 1  # Sometimes nmap test fails with no reply from server, _maybe_ this helps?
new "nmap test"

expectpart "$(nmap --script ssl* -p 443 127.0.0.1)" 0 "443/tcp open  https" "least strength: A" "Nmap done: 1 IP address (1 host up) scanned in" --not-- "No reply from server" "TLSv1.0:" "TLSv1.1:"

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
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

# unset conditional parameters
unset RCPROTO

# Set by restconf_config
unset RESTCONFIG
unset RESTCONFIG1

rm -rf $dir

new "endtest"
endtest
