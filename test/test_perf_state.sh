#!/usr/bin/env bash
# Scaling/ performance tests
# Config + state data, only get
# Restconf/Netconf/CLI
# Use mixed ietf-interfaces config+state

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

# Number of list/leaf-list entries in file (cant be less than 2)
: ${perfnr:=1000}

# Number of requests made get/put
: ${perfreq:=100}

APPNAME=example

cfg=$dir/config.xml
fconfig=$dir/large.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/example/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/example/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_CLI_GENMODEL_TYPE>VARS</CLICON_CLI_GENMODEL_TYPE>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
</clixon-config>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend -s init -f $cfg -- -s"
    start_backend -s init -f $cfg -- -s
fi

new "waiting"
wait_backend

new "kill old restconf daemon"
sudo pkill -u $wwwuser clixon_restconf

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_restconf

new "generate 'large' config with $perfnr list entries"
echo -n "<rpc><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">" > $fconfig
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<interface><name>e$i</name><type>ex:eth</type></interface>" >> $fconfig
done
echo "</interfaces></config></edit-config></rpc>]]>]]>" >> $fconfig

# Now take large config file and write it via netconf to candidate
new "netconf write large config"
expecteof_file "time $clixon_netconf -qf $cfg" 0 "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Now commit it from candidate to running 
new "netconf commit large config"
expecteof "time $clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

# START actual tests
# Having a large db, get single entries many times
# NETCONF get
new "netconf get test single req"
sel="/if:interfaces/if:interface[if:name='e1']"
msg="<rpc><get><filter type=\"xpath\" select=\"$sel\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"/></get></rpc>]]>]]>"
expecteof "$clixon_netconf -qf $cfg" 0 "$msg" '^<rpc-reply><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>e1</name><type>ex:eth</type><enabled>true</enabled><oper-status>up</oper-status><ex:my-status xmlns:ex="urn:example:clixon"><ex:int>42</ex:int><ex:str>foo</ex:str></ex:my-status></interface></interfaces></data></rpc-reply>]]>]]>$'

new "netconf get $perfreq single reqs"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    sel="/if:interfaces/if:interface[if:name='e$rnd']"
    echo "<rpc><get><filter type=\"xpath\" select=\"$sel\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"/></get></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg > /dev/null; } 2>&1 | awk '/real/ {print $2}'

# RESTCONF get
new "restconf get test single req"
expecteq "$(curl -s -X GET http://localhost/restconf/data/ietf-interfaces:interfaces/interface=e1)" 0 '{"ietf-interfaces:interface":[{"name":"e1","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}]}
'

new "restconf get $perfreq single reqs"
#echo "curl -sG http://localhost/restconf/data/ietf-interfaces:interfaces/interface=e0"
#curl -sG http://localhost/restconf/data/ietf-interfaces:interfaces/interface=e67

{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl -sG http://localhost/restconf/data/ietf-interfaces:interfaces/interface=e$rnd > /dev/null
done } 2>&1 | awk '/real/ {print $2}'

# CLI get
new "cli get test single req"
expectfn "$clixon_cli -1 -1f $cfg -l o show state xml interfaces interface e1" 0 '^<interface>
   <name>e1</name>
   <type>ex:eth</type>
   <enabled>true</enabled>
   <oper-status>up</oper-status>
</interface>$'

new "cli get $perfreq single reqs"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    $clixon_cli -1 -f $cfg show state xml interfaces interface e$rnd > /dev/null
done } 2>&1 | awk '/real/ {print $2}'

# Get config in one large get
new "netconf get large config"
time echo "<rpc><get> <filter type=\"xpath\" select=\"/if:interfaces\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"/></get></rpc>]]>]]>" | $clixon_netconf -qf $cfg > /tmp/netconf

new "restconf get large config"
time curl -sG http://localhost/restconf/data/ietf-interfaces:interfaces | wc

new "cli get large config"
time $clixon_cli -1f $cfg show state xml interfaces | wc

new "Kill restconf daemon"
stop_restconf 

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
