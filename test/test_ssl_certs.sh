#!/usr/bin/env bash
# Restconf+NACM openssl functionality using server and client certs
# The test creates certs and keys:
# A CA, server key/cert, user key/cert for two users
# Can we try illegal certs?

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Only works with evhtp and https
if [ "${WITH_RESTCONF}" != "evhtp" ]; then
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
srvkey=$certdir/srv_key.pem
srvcert=$certdir/srv_cert.pem
cakey=$certdir/ca_key.pem # needed?

cacert=$certdir/ca_cert.pem

users="andy guest" # generate certs for some users in nacm.sh

# Whether to generate new keys or not (only if $dir is not removed)
# Here dont generate keys if restconf started stand-alone (RC=0)
: ${genkeys:=true}
if [ $RC -eq 0 ]; then
    genkeys=false
fi

test -d $certdir || mkdir $certdir

# Use yang in example

# Get config from backend?
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
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_SSL_SERVER_CERT>$srvcert</CLICON_SSL_SERVER_CERT>
  <CLICON_SSL_SERVER_KEY>$srvkey</CLICON_SSL_SERVER_KEY>
  <CLICON_SSL_CA_CERT>$cacert</CLICON_SSL_CA_CERT>
EOF

if $IPv6; then
    cat <<EOF >> $cfg
    <CLICON_RESTCONF_IPV6_ADDR>::</CLICON_RESTCONF_IPV6_ADDR>
EOF
fi

cat <<EOF >> $cfg
</clixon-config>
EOF

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

    # Server certs
    . ./certs.sh

    # create client certs
    for name in $users; do
	cat<<EOF > $dir/$name.cnf
[req]
prompt = no
distinguished_name = dn
[dn]
CN = $name
emailAddress = $name@foo.bar
O = Clixon
L = Stockholm
C = SE
EOF
	# Create client key
	openssl genrsa -out "$certdir/$name.key" 2048

	# Generate CSR (signing request)
	openssl req -new -config $dir/$name.cnf -key $certdir/$name.key -out $certdir/$name.csr

	# Sign by CA
	openssl x509 -req -extfile $dir/$name.cnf -days 1 -passin "pass:password" -in $certdir/$name.csr -CA $cacert -CAkey $cakey -CAcreateserial -out $certdir/$name.crt
    done # client key

fi # genkeys

# Set a clixon-restconf config
if [ ${RCPROTO} = "https" ]; then
    ssl=true
    port=443
else
    ssl=false
    port=80
fi
authtype=client-certificate

# Run with and without getting config from backend
# arg 1: false: local config; true: use config backend 
testrun()
{
    USEBACKEND=$1

    # Startup DB with proper NACM config
    if $USEBACKEND; then
	cat <<EOF > $dir/startup_db
    <config>
       <restconf xmlns="https://clicon.org/restconf">
         <auth-type>$authtype</auth-type>
         <ssl-enable>true</ssl-enable>
         <server-cert-path>$srvcert</server-cert-path>
         <server-key-path>$srvkey</server-key-path>
         <server-ca-cert-path>$cacert</server-ca-cert-path>

         <socket>
           <namespace>default</namespace>
           <address>0.0.0.0</address>
           <port>$port</port>
           <ssl>$ssl</ssl>
         </socket>
       </restconf>
       $RULES
    </config>
EOF
    else
	cat <<EOF > $dir/startup_db
    <config>
       $RULES
    </config>
EOF
    fi
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
	if $USEBACKEND; then
	    new "start restconf daemon -b -- -s"
	    start_restconf -f $cfg -b -- -s
	else
	    new "start restconf daemon -s -c  -- -s"
	    start_restconf -f $cfg -s -c -- -s
	fi
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

new "Use local restconf config"
testrun false

new "Get restconf config from backend"
testrun true

rm -rf $dir

# unset conditional parameters
unset RCPROTO
