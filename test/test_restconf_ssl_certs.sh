#!/usr/bin/env bash
# Restconf+NACM openssl functionality using server and client certs
# The test creates certs and keys:
# A CA, server key/cert, user key/cert for two users
# Can we try illegal certs?

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Only works with native and https
if [ "${WITH_RESTCONF}" != "native" ]; then
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

RCPROTO=https

APPNAME=example

# Common NACM scripts
. ./nacm.sh

fyang=$dir/example.yang

cfg=$dir/conf.xml

# Local for test here
certdir=$dir/certs
cakey=$certdir/ca_key.pem
cacert=$certdir/ca_cert.pem
srvkey=$certdir/srv_key.pem
srvcert=$certdir/srv_cert.pem

# These is another CA (invalid) for creating invalid client certs
xcakey=$certdir/xca_key.pem
xcacert=$certdir/xca_cert.pem

users="andy guest" # generate certs for some users in nacm.sh

x1users="limited"   # Set invalid cert
#x2users="invalid"   # Wrong CA
x3users="mymd5"     # Too weak ca 

# Whether to generate new keys or not (only if $dir is not removed)
# Here dont generate keys if restconf started stand-alone (RC=0)
: ${genkeys:=true}
#if [ $RC -eq 0 ]; then
#    genkeys=false
#fi

test -d $certdir || mkdir $certdir

# Use yang in example
cat <<EOF > $fyang
module example{
  yang-version 1.1;
  namespace "urn:example:example";
  prefix ex;
  import ietf-netconf-acm {
	prefix nacm;
  }
  leaf x{
    type int32;
    description "something to edit";
  }
}
EOF

# Two groups: admin allow all, guest allow nothing
RULES=$(cat <<EOF
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>false</enable-nacm>
     <read-default>permit</read-default>
     <write-default>deny</write-default>
     <exec-default>deny</exec-default>

     $NGROUPS

     <rule-list>
       <name>guest-acl</name>
       <group>guest</group>
       <rule>
         <name>deny-ncm</name>
         <module-name>*</module-name>
         <access-operations>*</access-operations>
         <action>deny</action>
         <comment>
             Do not allow guests any access to the NETCONF
         </comment>
       </rule>
     </rule-list>

     $NADMIN

   </nacm>
   <x xmlns="urn:example:example">0</x>
EOF
)

if $genkeys; then
    # Create server certs
    cacerts $cakey $cacert
    servercerts $cakey $cacert $srvkey $srvcert

    # Other (invalid)
    cacerts $xcakey $xcacert
    
    # create client certs
    for name in $users $x1users; do
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
    done # client key

    # invalid (days = 0)
    for name in $x1users; do
	openssl x509 -req -extfile $dir/$name.cnf -days 0 -passin "pass:password" -in $certdir/$name.csr -CA $cacert -CAkey $cakey -CAcreateserial -out $certdir/$name.crt ||  err "Generate signing client cert"
    done # invalid

    
        # create client certs with md5 -- too weak ca
    for name in $x3users; do
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
	openssl x509 -req -extfile $dir/$name.cnf -days 1 -passin "pass:password" -in $certdir/$name.csr -CA $cacert -CAkey $cakey -CAcreateserial -md5 -out $certdir/$name.crt  ||  err "Generate signing client cert"
    done # too weak ca
    
    if false; then # XXX: How do you generate an "invalid" cert?
    # create client certs from invalid CA
    for name in $x2users; do
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
	openssl x509 -req -extfile $dir/$name.cnf -days 1 -passin "pass:password" -in $certdir/$name.csr -CA $xcacert -CAkey $xcakey -CAcreateserial -out $certdir/$name.crt
    done # invalid ca
    fi # XXX

fi # genkeys

# Write local config
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_UPGRADE_CHECKOLD>true</CLICON_XMLDB_UPGRADE_CHECKOLD>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
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

# Run The test, ssl config is in local config
function testrun()
{
    cat <<EOF > $dir/startup_db
    <${DATASTORE_TOP}>
       $RULES
    </${DATASTORE_TOP}>
EOF
    if [ $BE -ne 0 ]; then
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	sudo pkill -f clixon_backend # to be sure
	
	new "start backend -s startup -f $cfg"
	start_backend -s startup -f $cfg
    fi

    new "wait for backend"
    wait_backend

    if [ $RC -ne 0 ]; then
	new "kill old restconf daemon"
	stop_restconf_pre
	new "start restconf daemon -s -c"
	start_restconf -f $cfg
    fi

    new "wait for restconf"
    wait_restconf --key $certdir/andy.key --cert $certdir/andy.crt

    new "enable nacm"
    expectpart "$(curl $CURLOPTS --key $certdir/andy.key --cert $certdir/andy.crt -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-netconf-acm:enable-nacm": true}' $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 "HTTP/1.1 204 No Content"

    new "admin get x"
    expectpart "$(curl $CURLOPTS --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:x)" 0 "HTTP/1.1 200 OK" '{"example:x":0}'

    new "guest get x"
    expectpart "$(curl $CURLOPTS --key $certdir/guest.key --cert $certdir/guest.crt -X GET $RCPROTO://localhost/restconf/data/example:x)" 0 "HTTP/1.1 403 Forbidden" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'

    new "admin set x 42"
    expectpart "$(curl $CURLOPTS --key $certdir/andy.key --cert $certdir/andy.crt -X PUT -H "Content-Type: application/yang-data+json" -d '{"example:x":42}' $RCPROTO://localhost/restconf/data/example:x)" 0 "HTTP/1.1 204 No Content"

    new "admin set x 42 without media"
    expectpart "$(curl $CURLOPTS --key $certdir/andy.key --cert $certdir/andy.crt -X PUT -d '{"example:x":42}' $RCPROTO://localhost/restconf/data/example:x)" 0 "HTTP/1.1 415 Unsupported Media Type" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-not-supported","error-severity":"error","error-message":"Unsupported Media Type"}}}'

    new "admin get x 42"
    expectpart "$(curl $CURLOPTS --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:x)" 0 "HTTP/1.1 200 OK" '{"example:x":42}'

    # Negative tests
    new "Unknown yyy no cert get x 42"
    echo "dummy" > $certdir/yyy.key
    echo "dummy" > $certdir/yyy.crt
    expectpart "$(curl $CURLOPTS --key $certdir/yyy.key --cert $certdir/yyy.crt -X GET $RCPROTO://localhost/restconf/data/example:x 2>&1)" 58 " could not load PEM client certificate"

    # See (3) client-cert is NULL in restconf_main_openssl.c
    new "No cert: certificate required"
    expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:x 2>&1)" 0 "HTTP/1.1 400 Bad Request"

    new "limited invalid cert"
    expectpart "$(curl $CURLOPTS --key $certdir/limited.key --cert $certdir/limited.crt -X GET $RCPROTO://localhost/restconf/data/example:x 2>&1)" "35 55 56" # 55 "certificate expired"

    new "too weak cert (sign w md5)"
    expectpart "$(curl $CURLOPTS --key $certdir/mymd5.key --cert $certdir/mymd5.crt -X GET $RCPROTO://localhost/restconf/data/example:x 2>&1)" 58 "md too weak"

# Havent been able to generate "wrong CA"
#    new "invalid cert from wrong CA"
#    expectpart "$(curl $CURLOPTS --key $certdir/invalid.key --cert $certdir/invalid.crt -X GET $RCPROTO://localhost/restconf/data/example:x 2>&1)" 0 foo # 58 "unable to set private key file" # 58 unable to set private key file

    # Just ensure all is OK
    new "admin get x 42"
    expectpart "$(curl $CURLOPTS --key $certdir/andy.key --cert $certdir/andy.crt -X GET $RCPROTO://localhost/restconf/data/example:x)" 0 "HTTP/1.1 200 OK" '{"example:x":42}'

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
}

new "Run test"
testrun 

rm -rf $dir

# unset conditional parameters
unset RCPROTO

endtest
