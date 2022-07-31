#!/usr/bin/env bash
# test of Restconf callhome
# See RFC 8071 NETCONF Call Home and RESTCONF Call Home
# No NACM for now

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Only works with native
if [ "${WITH_RESTCONF}" != "native" ]; then
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

: ${clixon_restconf_callhome_client:=clixon_restconf_callhome_client}

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang
clispec=$dir/spec.cli

certdir=$dir/certs
cakey=$certdir/ca_key.pem
cacert=$certdir/ca_cert.pem
srvkey=$certdir/srv_key.pem
srvcert=$certdir/srv_cert.pem

users="andy" # generate certs for some users

RCPROTO=https
# Callhome stream is HTTP/1.1, other communication is HTTP/2
HVER=2
HVERCH=1.1

test -d $certdir || mkdir $certdir

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>	
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <restconf>
     <enable>true</enable>
     <auth-type>client-certificate</auth-type>
     <pretty>false</pretty>
     <server-cert-path>$srvcert</server-cert-path>
     <server-key-path>$srvkey</server-key-path>
     <server-ca-cert-path>$cacert</server-ca-cert-path>
     <debug>1</debug>
     <socket>
        <namespace>default</namespace>
	<call-home>
	   <connection-type>
	      <persistent/>
	   </connection-type>
	</call-home>
        <address>127.0.0.1</address>
        <port>4336</port>
        <ssl>true</ssl>
      </socket>
      <socket>
         <namespace>default</namespace>
         <address>0.0.0.0</address>
         <port>443</port>
         <ssl>true</ssl>
      </socket>
  </restconf>
  <autocli>
     <module-default>false</module-default>
     <list-keyword-default>kw-nokey</list-keyword-default>
     <treeref-state-default>false</treeref-state-default>
     <rule>
       <name>include clixon-example</name>
       <operation>enable</operation>
       <module-name>clixon-example</module-name>
     </rule>
     <rule>
       <name>include ietf-netconf-server</name>
       <operation>enable</operation>
       <module-name>ietf-netconf-server</module-name>
     </rule>
     <rule>
       <name>include ietf-keystore</name>
       <operation>enable</operation>
       <module-name>ietf-keystore</module-name>
     </rule>
     <rule>
       <name>include ietf-truststore</name>
       <operation>enable</operation>
       <module-name>ietf-truststore</module-name>
     </rule>
  </autocli>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   /* Generic config data */
   container table{
      list parameter{
         key name;
	 leaf name{
	    type string;
	 }
	 leaf value{
	    type string;
         }
      }
   }
}
EOF

cat <<EOF > $clispec
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") @datamodel, cli_auto_del();
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "text", true, false);{
	    xml("Show configuration as XML"), cli_auto_show("datamodel", "candidate", "xml", true, false);
	    cli("Show configuration as CLI commands"), cli_auto_show("datamodel", "candidate", "cli", false, false, "set ");
	    netconf("Show configuration as netconf edit-config operation"), cli_auto_show("datamodel", "candidate", "netconf", false, false);
	    text("Show configuration as text"), cli_auto_show("datamodel", "candidate", "text", false, false);
	    json("Show configuration as JSON"), cli_auto_show("datamodel", "candidate", "json", false, false);
    }
    state("Show configuration and state"), cli_auto_show("datamodel", "running", "xml", false, true);
}
EOF

# Create server certs
cacerts $cakey $cacert
servercerts $cakey $cacert $srvkey $srvcert

# Create client certs

for name in $users; do
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
    openssl x509 -req -extfile $dir/$name.cnf -days 7 -passin "pass:password" -in $certdir/$name.csr -CA $cacert -CAkey $cakey -CAcreateserial -out $certdir/$name.crt  ||  err "Generate signing client cert"
done

# hardcoded to andy
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
</${DATASTORE_TOP}>
EOF

# Callhome request from client
cat <<EOF > $dir/data
GET /restconf/data HTTP/$HVERCH
Host: localhost
Accept: application/yang-data+xml

EOF

new "test params: -f $cfg"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend  -s startup -f $cfg"
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

new "restconf Add init data"
expectpart "$(curl $CURLOPTS  --key $certdir/andy.key --cert $certdir/andy.crt -X POST -H "Accept: application/yang-data+json" -H "Content-Type: application/yang-data+json" -d '{"clixon-example:table":{"parameter":{"name":"x","value":"foo"}}}' $RCPROTO://127.0.0.1/restconf/data)" 0 "HTTP/$HVER 201"

new "Send GET via callhome client"
expectpart "$(${clixon_restconf_callhome_client} -D $DBG -f $dir/data -a 127.0.0.1 -c $srvcert -k $srvkey -C $cacert)" 0 "HTTP/$HVERCH 200 OK" "Content-Type: application/yang-data+xml"

# Kill old
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
