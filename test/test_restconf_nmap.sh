#!/usr/bin/env bash
# Restconf basic functionality also uri encoding using eth/0/0
# NMAP ssl script testing.
# The following tests are run:
# - ssl-ccs-injection, but not deterministic, need to repeat (10 times) maybe this is wrong?
# - ssl-cert-intaddr
# - ssl-cert
# - ssl-date
# - ssl-dh-params
# - ssl-enum-ciphers
# - ssl-heartbleed
# - ssl-known-key
# - ssl-poodle
# - sslv2-drown
# - sslv2

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Only works with native and https
if [ "${WITH_RESTCONF}" != "native" ]; then
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

RCPROTO=https
APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/clixon-example.yang

# If nmap not installed just quietly quit
if [ ! -n "$(type nmap 2> /dev/null)" ]; then
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

# clixon-restconf is used in the test, need local copy
# This is a kludge: look in src otherwise assume it is installed in /usr/local/share
# Note that revisions may change and may need to be updated

y=clixon-restconf@${CLIXON_RESTCONF_REV}.yang
if [ -d ${TOP_SRCDIR}/yang/clixon ]; then 
    cp ${TOP_SRCDIR}/yang/clixon/$y $dir/
else
    cp /usr/local/share/clixon/$y $dir/
fi

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
}
EOF

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
fi

# Create a single IPv4 https socket
RESTCONFIG=$(cat <<EOF
<restconf>
   <enable>true</enable>
   <auth-type>none</auth-type>
   <server-cert-path>$srvcert</server-cert-path>
   <server-key-path>$srvkey</server-key-path>
   <server-ca-cert-path>$cakey</server-ca-cert-path>
   <pretty>false</pretty>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>443</port><ssl>true</ssl></socket>
</restconf>
EOF
)


# Clixon config
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
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
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_BACKEND_RESTCONF_PROCESS>false</CLICON_BACKEND_RESTCONF_PROCESS>
  $RESTCONFIG
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

# Explicit start of restconf for easier debugging
if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre
    
    new "start restconf daemon"
    # inline of start_restconf, cant make quotes to work
    echo "sudo -u $wwwstartuser -s $clixon_restconf $RCLOG -D $DBG -f $cfg"
    sudo -u $wwwstartuser -s $clixon_restconf $RCLOG -D $DBG -f $cfg &
    if [ $? -ne 0 ]; then
	err1 "expected 0" "$?"
    fi
fi

new "wait restconf"
wait_restconf

# Try 10 times, dont know why this is undeterministic?
let i=0;
new "nmap ssl-ccs-injection$i"
result=$(nmap --script ssl-ccs-injection -p 443 127.0.0.1)
# echo "result:$result"
while [[ "$result" = *"No reply from server"* ]]; do
    if [ $i -ge 10 ]; then
	err "ssl-ccs-injection"
    fi
    sleep 1
    let i++;
    new "nmap ssl-ccs-injection$i"
    result=$(nmap --script ssl-ccs-injection -p 443 127.0.0.1)
    # echo "result:$result"
done

new "nmap ssl-cert-intaddr"
expectpart "$(nmap --script ssl-cert-intaddr -p 443 127.0.0.1)" 0 "443/tcp open  https"

new "nmap ssl-cert"
expectpart "$(nmap --script ssl-cert -p 443 127.0.0.1)" 0 "443/tcp open  https" "| ssl-cert: Subject: commonName=www.clicon.org/organizationName=Clixon/countryName=SE"

new "nmap ssl-date"
expectpart "$(nmap --script ssl-date -p 443 127.0.0.1)" 0 "443/tcp open  https"

new "nmap ssl-dh-params"
expectpart "$(nmap --script ssl-dh-params -p 443 127.0.0.1)" 0 "443/tcp open  https"

new "nmap ssl-enum-ciphers"
expectpart "$(nmap --script ssl-enum-ciphers -p 443 127.0.0.1)" 0 "443/tcp open  https" "least strength: A" "TLSv1.2" --not-- "No reply from server" "TLSv1.0:" "TLSv1.1:"

new "nmap ssl-heartbleed"
expectpart "$(nmap --script ssl-heartbleed -p 443 127.0.0.1)" 0 "443/tcp open  https"

new "nmap ssl-known-key"
expectpart "$(nmap --script ssl-known-key -p 443 127.0.0.1)" 0 "443/tcp open  https"

new "nmap ssl-poodle"
expectpart "$(nmap --script ssl-poodle -p 443 127.0.0.1)" 0 "443/tcp open  https"

new "nmap sslv2-drown"
expectpart "$(nmap --script sslv2-drown -p 443 127.0.0.1)" 0 "443/tcp open  https"

new "nmap sslv2"
expectpart "$(nmap --script sslv2 -p 443 127.0.0.1)" 0 "443/tcp open  https"

new "restconf get. Just ensure restconf is alive"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://127.0.0.1/.well-known/host-meta)" 0 "HTTP/$HVER 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"

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
unset result
unset RESTCONFIG

rm -rf $dir

new "endtest"
endtest
