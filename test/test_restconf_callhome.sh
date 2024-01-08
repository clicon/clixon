#!/usr/bin/env bash
# test of Restconf callhome
# See RFC 8071 NETCONF Call Home and RESTCONF Call Home
# Simple NACM for single "andy" user
# The client is clixon_restconf_callhome_client that waits for accept, connects, sends a GET immediately,
# closes the socket and re-listens
# The server opens three sockets:
# 1) regular listen socket for setting init value
# 2) persistent socket
# 3) periodic socket (10s) port 8336
# XXX periodic: idle-timeout not properly tested

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Only works with native
if [ "${WITH_RESTCONF}" != "native" ]; then
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

if ! ${HAVE_HTTP1}; then
    echo "...skipped: Must run with http/1"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# Callhome stream pin to HTTP/1.1, other communication is HTTP/2 if present
HVERCH=1.1

: ${clixon_restconf_callhome_client:=clixon_restconf_callhome_client}

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang
clispec=$dir/spec.cli

# HTTP request client->server 
frequest=$dir/frequest
# HTTP expected reply server->client

# Duration of time between periodic connections (in seconds)
PERIOD_S=10

# Maximum number of seconds the underlying TCP session may remain idle (in seconds)
IDLE_TIMEOUT_S=5

certdir=$dir/certs
cakey=$certdir/ca_key.pem
cacert=$certdir/ca_cert.pem
srvkey=$certdir/srv_key.pem
srvcert=$certdir/srv_cert.pem

users="andy" # generate certs for some users

RCPROTO=https

test -d $certdir || mkdir $certdir

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE> 
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
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
        <description>callhome persistent</description>
        <namespace>default</namespace>
        <call-home>
           <connection-type>
              <persistent/>
           </connection-type>
           <reconnect-strategy>
              <max-attempts>1</max-attempts>
           </reconnect-strategy>
        </call-home>
        <address>127.0.0.1</address>
        <port>4336</port>
        <ssl>true</ssl>
      </socket>
      <socket>
        <description>callhome periodic</description>
        <namespace>default</namespace>
        <call-home>
           <connection-type>
              <periodic>
                <period>${PERIOD_S}</period>
                <idle-timeout>${IDLE_TIMEOUT_S}</idle-timeout>
              </periodic>
           </connection-type>
           <reconnect-strategy>
              <max-attempts>3</max-attempts>
           </reconnect-strategy>
        </call-home>
        <address>127.0.0.1</address>
        <port>8336</port>
        <ssl>true</ssl>
      </socket>
      <socket>
         <description>listen</description>      
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
   import ietf-netconf-acm {
      prefix nacm;
   }
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

# NACM rules
# Two groups: admin allow all, guest allow nothing
RULES=$(cat <<EOF
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>false</enable-nacm>
     <read-default>permit</read-default>
     <write-default>deny</write-default>
     <exec-default>deny</exec-default>
     <groups>
       <group>
         <name>admin</name>
         <user-name>andy</user-name>
       </group>
     </groups>
     <rule-list>
       <name>admin-acl</name>
       <group>admin</group>
       <rule>
         <name>permit-all</name>
         <module-name>*</module-name>
         <access-operations>*</access-operations>
         <action>permit</action>
         <comment>
             Allow the 'admin' group complete access to all operations and data.
         </comment>
       </rule>
     </rule-list>
   </nacm>
EOF
)

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
    configuration("Show configuration"), cli_show_auto_mode("candidate", "text", true, false);{
            xml("Show configuration as XML"), cli_show_auto_mode("candidate", "xml", true, false);
            cli("Show configuration as CLI commands"), cli_show_auto_mode("candidate", "cli", false, false, "report-all", "set ");
            netconf("Show configuration as netconf edit-config operation"), cli_show_auto_mode("candidate", "netconf", false, false);
            text("Show configuration as text"), cli_show_auto_mode("candidate", "text", false, false);
            json("Show configuration as JSON"), cli_show_auto_mode("candidate", "json", false, false);
    }
    state("Show configuration and state"), cli_show_auto_mode("running", "xml", false, true);
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

# Just NACM for now
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
     $RULES
</${DATASTORE_TOP}>
EOF

# Callhome request from client->server
cat <<EOF > $frequest
GET /restconf/data/clixon-example:table HTTP/$HVERCH
Host: localhost
Accept: application/yang-data+xml

EOF

expectreply="<table xmlns=\"urn:example:clixon\"><parameter><name>x</name><value>foo</value></parameter></table>"

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
    start_restconf -f $cfg -D 1 -l s # XXX DONT debug
fi

new "wait restconf"
wait_restconf

new "restconf Add init data"
expectpart "$(curl $CURLOPTS --key $certdir/andy.key --cert $certdir/andy.crt -X POST -H "Accept: application/yang-data+json" -H "Content-Type: application/yang-data+json" -d '{"clixon-example:table":{"parameter":{"name":"x","value":"foo"}}}' $RCPROTO://127.0.0.1/restconf/data)" 0 "HTTP/$HVER 201"

t0=$(date +"%s")
new "Send GET via callhome persistence client port 4336"
expectpart "$(${clixon_restconf_callhome_client} -p 4336 -D $DBG -f $frequest -a 127.0.0.1 -c $srvcert -k $srvkey -C $cacert -e 2 -n 3)" 0 "HTTP/$HVERCH 200" "Reply: 1" "Close: 1 local" "Reply: 2" "Close: 2 local" "Reply: 3" "Close: 3 local"  $expectreply --not-- "Reply: 4" "Close: 4"
t1=$(date +"%s")

let t=t1-t0
new "Check persistent interval ($t) is in interval [2,4]"
if [ $t -lt 2 -o $t -gt 4 ]; then
    err1 "timer in interval [2,4] but is: $t"
fi

t0=$(date +"%s")
new "Send GET via callhome client periodic port 8336"
expectpart "$(${clixon_restconf_callhome_client} -t 30 -p 8336 -D $DBG -f $frequest -a 127.0.0.1 -c $srvcert -k $srvkey -C $cacert -e 2 -n 2)" 0 "HTTP/$HVERCH 200" "Reply: 1" "Close: 1" "Reply: 2" "Close: 2" $expectreply --not-- "Reply: 3" "Close: 3"
t1=$(date +"%s")

let t=t1-t0
new "Check periodic interval ($t) is in interval [10-21]"
if [ $t -lt 10 -o $t -gt 21 ]; then
    err1 "timer in interval [10-21] but is: $t"
fi

t0=$(date +"%s")
new "Send GET via callhome persistence again"
expectpart "$(${clixon_restconf_callhome_client} -p 4336 -D $DBG -f $frequest -a 127.0.0.1 -c $srvcert -k $srvkey -C $cacert -e 2 -n 3)" 0 "HTTP/$HVERCH 200" "Reply: 1" "Close: 1 local" "Reply: 2" "Close: 2 local" "Reply: 3" "Close: 3 local"  $expectreply --not-- "Reply: 4" "Close: 4"
t1=$(date +"%s")

let t=t1-t0
new "Check persistent interval ($t) is in interval [2,4]"
if [ $t -lt 2 -o $t -gt 4 ]; then
    err1 "timer in interval [2,4] but is: $t"
fi

t0=$(date +"%s")
new "Send GET: idle-timeout, client keeps socket open, server closes"
expectpart "$(${clixon_restconf_callhome_client} -t 60 -p 8336 -D 0 -f $frequest -a 127.0.0.1 -c $srvcert -k $srvkey -C $cacert -e 2 -n 2 -i)" 0 "HTTP/$HVERCH 200" "Accept: 1" "Reply: 1" $expectreply "Close: 1 remote" "Accept: 2" "Reply: 2" "Close: 2" --not-- "Accept: 3"
t1=$(date +"%s")

let t=t1-t0
new "Check periodic interval ($t) is in interval [15-30]"
if [ $t -lt 15 -o $t -gt 30 ]; then
    err1 "timer in interval [15-30] but is: $t"
fi

t0=$(date +"%s")

new "Send GET: idle-timeout, client sends data then idle, server closes"
expectpart "$(${clixon_restconf_callhome_client} -t 60 -p 8336 -D 0 -f $frequest -a 127.0.0.1 -c $srvcert -k $srvkey -C $cacert -e 2 -n 2 -i -d 3)" 0 "HTTP/$HVERCH 200" "Accept: 1" "Reply: 1" $expectreply "Close: 1 remote" "Accept: 2" "Reply: 2" "Close: 2" --not-- "Accept: 3"

t1=$(date +"%s")

let t=t1-t0
new "Check periodic interval ($t) is in interval [15-30]"
if [ $t -lt 15 -o $t -gt 30 ]; then
    err1 "timer in interval [15-30] but is: $t"
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
