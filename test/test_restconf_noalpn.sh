#!/usr/bin/env bash
# Restconf TLS no alpn functionality
# Test of CLICON_RESTCONF_NOALPN_DEFAULT AND client certs
# Also client certs (reason is usecase was POSTMAN w client certs)

dir=/tmp/test_restconf_noalpn.sh
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Only works with native and https
if [ "${WITH_RESTCONF}" != "native" ]; then
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

# Only works with both http/1 and http/2
if [ ${HAVE_LIBNGHTTP2} = false -o ${HAVE_HTTP1} = false ]; then    
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/restconf.yang

# Define default restconfig config: RESTCONFIG
# RESTCONFIG=$(restconf_config none false)

# Local for test here
certdir=$dir/certs
test -d $certdir || mkdir $certdir

cakey=$certdir/ca_key.pem
cacert=$certdir/ca_cert.pem
srvkey=$certdir/srv_key.pem
srvcert=$certdir/srv_cert.pem

echo "cakey:$cakey"
echo "srvkey:$srvkey"
echo "srvcert:$srvcert"

# Create server certs
cacerts $cakey $cacert
servercerts $cakey $cacert $srvkey $srvcert

name="andy"

cat<<EOF > $dir/$name.cnf
[req]
prompt = no
distinguished_name = dn
[dn]
CN = $name # This can be verified using SSL_set1_host
emailAddress = $name@foo.bar
O = Clixon
L = Stockholm
C = SE
EOF

# Create client key
openssl genpkey -algorithm RSA -out "$certdir/$name.key" ||  err "Generate client key"

# Generate CSR (signing request)
openssl req -new -config $dir/$name.cnf -key $certdir/$name.key -out $certdir/$name.csr

# Sign by CA
openssl x509 -req -extfile $dir/$name.cnf -days 1 -passin "pass:password" -in $certdir/$name.csr -CA $cacert -CAkey $cakey -CAcreateserial -out $certdir/$name.crt  ||  err "Generate signing client cert"

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <restconf>
     <enable>true</enable>
     <auth-type>client-certificate</auth-type>
     <server-cert-path>$srvcert</server-cert-path>
     <server-key-path>$srvkey</server-key-path>
     <server-ca-cert-path>$cacert</server-ca-cert-path>
     <debug>$DBG</debug>
     <pretty>false</pretty>
     <socket>
        <namespace>default</namespace>
        <address>0.0.0.0</address>
        <port>443</port>
        <ssl>true</ssl>
     </socket>
  </restconf>
</clixon-config>
EOF

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   container interfaces{
      list interface{
        key name;
        leaf name{
          type string;
        }
        leaf type{
          mandatory true;
          type string;
        }
      }
   }
}
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend # to be sure

    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

if false; then
new "netconf POST initial tree"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><interfaces xmlns=\"urn:example:clixon\"><interface><name>local0</name><type>regular</type></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"



if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg -o CLICON_NOALPN_DEFAULT=
fi

new "wait restconf"
wait_restconf

new "restconf GET http1 no-alpn expect reset"
expectpart "$(curl $CURLOPTS --http1.1 --no-alpn --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:interfaces/interface=local0)" "16 52 55 56"

new "restconf GET http2 no-alpn expect reset"
expectpart "$(curl $CURLOPTS --http2 --no-alpn --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:interfaces/interface=local0)" "16 52 55 56"

new "restconf GET http2 no-alpn expect reset"
expectpart "$(curl $CURLOPTS --http2-prior-knowledge --no-alpn --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:interfaces/interface=local0)" "16 52 55 56"

fi

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg -o "CLICON_NOALPN_DEFAULT=http/1.1" -D 1 -l f/tmp/restconf.log
fi

new "wait restconf"
wait_restconf

new "restconf GET http/1 default http/1 no-alpn"
#expectpart "$(curl $CURLOPTS --http1.1 --no-alpn --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:interfaces/interface=local0)" 0 "HTTP/1.1 200" '{"example:interface":\[{"name":"local0","type":"regular"}\]}'

new "restconf GET http/1 default http/2 no-alpn"
#expectpart "$(curl $CURLOPTS --http2 --no-alpn --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:interfaces/interface=local0)" 0 "HTTP/1.1 200" '{"example:interface":\[{"name":"local0","type":"regular"}\]}'

# XXX This leaks memory in restconf
new "restconf GET http/1 default http/2 prior-knowledge no-alpn, expect fail"
expectpart "$(curl $CURLOPTS --http2-prior-knowledge --no-alpn --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:interfaces/interface=local0)" "16 52 55 56"

if false; then

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg -o "CLICON_NOALPN_DEFAULT=http/2"
fi

new "wait restconf"
wait_restconf

# XXX ./test_restconf_noalpn.sh: line 193: warning: command substitution: ignored null byte in input
new "restconf GET http1 default http2 no-alpn expect fail"
expectpart "$(curl $CURLOPTS --http1.1 --no-alpn --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:interfaces/interface=local0 > /dev/null)" 0 --not-- HTTP

new "restconf GET http2 default http2 no-alpn expect fail"
expectpart "$(curl $CURLOPTS --http2 --no-alpn --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:interfaces/interface=local0 2> /dev/null)" 0 --not-- HTTP

new "restconf GET http2 default http2 no-alpn expect fail"
expectpart "$(curl $CURLOPTS --http2-prior-knowledge --no-alpn --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:interfaces/interface=local0)" 0 "HTTP/2 200" '{"example:interface":\[{"name":"local0","type":"regular"}\]}'

fi

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

rm -rf $dir

new "endtest"
endtest
