#!/usr/bin/env bash
# test of Netconf listen TLS
# XXX: more than one endpoint?

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

: ${clixon_netconf_tls:=clixon_netconf_tls}
: ${clixon_util_tls_client:=clixon_util_tls_client}

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang
clispec=$dir/spec.cli

certdir=$dir/certs
cakey=$certdir/ca_key.pem
cacert=$certdir/ca_cert.pem
srvkey=$certdir/srv_key.pem # X
srvcert=$certdir/srv_cert.pem # X

users="andy" # generate certs for some users

test -d $certdir || mkdir $certdir

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-netconf-server:ssh-listen</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-netconf-server:ssh-call-home</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-netconf-server:tls-listen</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-netconf-server:tls-call-home</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-netconf-server:central-netconf-server-supported</CLICON_FEATURE>

  <!--CLICON_FEATURE>ietf-keystore:*</CLICON_FEATURE-->
  <CLICON_FEATURE>ietf-keystore:central-keystore-supported</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-keystore:local-definitions-supported</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-keystore:asymmetric-keys</CLICON_FEATURE>

  <!--CLICON_FEATURE>ietf-truststore:*</CLICON_FEATURE-->
  <CLICON_FEATURE>ietf-truststore:central-truststore-supported</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-truststore:local-definitions-supported</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-truststore:certificates</CLICON_FEATURE>

  <CLICON_FEATURE>ietf-tls-server:tls-server-keepalives</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-tls-server:server-ident-x509-cert</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-tls-server:client-auth-supported</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-tls-server:client-auth-x509-cert</CLICON_FEATURE>

  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_STANDARD_DIR}/../experimental/ietf-extracted-YANG-modules</CLICON_YANG_DIR>  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>	
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
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
  import ietf-netconf-server {
    prefix ncs;    
  }
 import ietf-keystore {
    prefix ks;
    reference
      "RFC CCCC: A YANG Data Model for a Keystore";
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
<keystore xmlns="urn:ietf:params:xml:ns:yang:ietf-keystore">
    <asymmetric-keys>
        <asymmetric-key>
            <name>serverkey</name>
            <public-key-format>ct:subject-public-key-info-format</public-key-format>
            <public-key>xxx</public-key>
	    <private-key-format>ct:rsa-private-key-format</private-key-format>
            <cleartext-private-key>$(cat $srvkey)</cleartext-private-key>
            <certificates>
                <certificate>
                    <name>servercert</name>
                    <cert-data>$(cat $srvcert)</cert-data>
                </certificate>
            </certificates>
        </asymmetric-key>
    </asymmetric-keys>
</keystore>
<truststore xmlns="urn:ietf:params:xml:ns:yang:ietf-truststore">
    <certificate-bags>
      <certificate-bag>
        <name>clientcerts</name>
        <certificate>
            <name>clientcert</name>
            <cert-data>$(cat $certdir/andy.key)</cert-data>
        </certificate>
      </certificate-bag>
      <certificate-bag>
        <name>cacerts</name>
        <certificate>
            <name>cacert</name>
            <cert-data>$(cat $cacert)</cert-data>
        </certificate>
      </certificate-bag>
    </certificate-bags>
</truststore>
<netconf-server xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-server">
    <listen>
        <endpoint>
            <name>default-tls</name>
            <tls>
                <tcp-server-parameters>
                    <local-address>0.0.0.0</local-address>
                    <keepalives>
                        <idle-time>1</idle-time>
                        <max-probes>10</max-probes>
                        <probe-interval>5</probe-interval>
                    </keepalives>
                </tcp-server-parameters>
                <tls-server-parameters>
                    <server-identity>
		      <certificate>
                        <keystore-reference>
                            <asymmetric-key>serverkey</asymmetric-key>
                            <certificate>servercert</certificate>
                        </keystore-reference>
		      </certificate>
                    </server-identity>
                    <client-authentication>
                        <ca-certs>
			  <truststore-reference>cacerts</truststore-reference>
			</ca-certs>
                        <ee-certs>
			  <truststore-reference>clientcerts</truststore-reference>
                         </ee-certs>
                        <!--cert-maps>
                            <cert-to-name>
                                <id>1</id>
                                <fingerprint>02:20:E1:AD:CC:92:71:E9:EA:6A:85:DF:A7:FF:8C:BB:B9:D5:E4:EE:74</fingerprint>
                                <map-type xmlns:x509c2n="urn:ietf:params:xml:ns:yang:ietf-x509-cert-to-name">x509c2n:specified</map-type>
                                <name>tls-test</name>
                            </cert-to-name>
                        </cert-maps-->
                    </client-authentication>
                </tls-server-parameters>
            </tls>
        </endpoint>
    </listen>
</netconf-server>
</${DATASTORE_TOP}>
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

new "start netconf-tls"
echo "${clixon_netconf_tls} -D $DBG -f $cfg"
sudo -u $wwwstartuser -s ${clixon_netconf_tls} -D $DBG -f $cfg &

# Hello
new "Netconf snd hello with xmldecl"
echo "$clixon_util_tls_client -D $DBG -d 127.0.0.1 -p 6501 -c $srvcert -k $srvkey"
expecteof_netconf "$clixon_util_tls_client -D $DBG -d 127.0.0.1 -p 6501 -c $srvcert -k $srvkey" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
exit
new "Kill netconf_tls daemon"
sudo pkill -f clixon_netconf_tls

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
