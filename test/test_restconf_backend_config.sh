#!/usr/bin/env bash
# New Restconf config using backend config
# DOES NOT WORK WITH FCGI

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Skip it other than evhtp
if [ "${WITH_RESTCONF}" != "evhtp" ]; then
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

APPNAME=example
cfg=$dir/conf.xml

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_CONFIG>true</CLICON_RESTCONF_CONFIG>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

if [ ${RCPROTO} = "https" ]; then
    ssl=true
    port=443
else
    ssl=false
    port=80
fi
cat<<EOF > $dir/startup_db
<config>
   <restconf xmlns="https://clicon.org/restconf">
      <socket>
         <namespace>default</namespace>
         <address>0.0.0.0</address>
         <port>$port</port>
         <ssl>$ssl</ssl>
      </socket>
      <auth-type>password</auth-type>
      <server-cert-path>/etc/ssl/certs/clixon-server-crt.pem</server-cert-path>
      <server-key-path>/etc/ssl/private/clixon-server-key.pem</server-key-path>
      <server-ca-cert-path>/etc/ssl/certs/clixon-ca_crt.pem</server-ca-cert-path>
      <client-cert-ca></client-cert-ca>
   </restconf>
</config>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg -s startup
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure

    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg

fi
new "wait restconf"
wait_restconf

new "restconf root discovery. RFC 8040 3.1 (xml+xrd)"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/.well-known/host-meta)" 0 'HTTP/1.1 200 OK' "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"

new "restconf get restconf resource. RFC 8040 3.3 (json)"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf)" 0 'HTTP/1.1 200 OK' '{"ietf-restconf:restconf":{"data":{},"operations":{},"yang-library-version":"2016-06-21"}}'

new "restconf get restconf resource. RFC 8040 3.3 (xml)"
# Get XML instead of JSON?
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf)" 0 'HTTP/1.1 200 OK' '<restconf xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><data/><operations/><yang-library-version>2016-06-21</yang-library-version></restconf>'

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
