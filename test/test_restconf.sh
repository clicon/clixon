#!/bin/bash
# Restconf basic functionality
# Assume http server setup, such as nginx described in apps/restconf/README.md

# include err() and new() functions and creates $dir
. ./lib.sh
cfg=$dir/conf.xml
fyang=$dir/restconf.yang

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/routing/yang</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>$fyang</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/routing/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/routing/backend</CLICON_BACKEND_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/routing/restconf</CLICON_RESTCONF_DIR>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_CLI_DIR>/usr/local/lib/routing/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>routing</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/routing/routing.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/routing/routing.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/routing</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

cat <<EOF > $fyang
module example{
    prefix ex;
    import ietf-ip {
      prefix ip;
    }
    import ietf-routing {
      prefix rt;
    }
    import ietf-inet-types {
       prefix "inet";
       revision-date "2013-07-15";
    }
    rpc empty {
    }
    rpc input {
       input {
       }
    }
    rpc output {
       output {
       }
    }
}
EOF

# This is a fixed 'state' implemented in routing_backend. It is assumed to be always there
state='{"interfaces-state": {"interface": {"name": "eth0","type": "eth","if-index": "42"}}}'

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err
fi
new "start backend -s init -f $cfg -y $fyang"
sudo clixon_backend -s init -f $cfg -y $fyang
if [ $? -ne 0 ]; then
    err
fi

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
sudo start-stop-daemon -S -q -o -b -x /www-data/clixon_restconf -d /www-data -c www-data -- -Df $cfg -D

sleep 1

new "restconf tests"

new "restconf options"
expectfn "curl -i -sS -X OPTIONS http://localhost/restconf/data" "Allow: OPTIONS,HEAD,GET,POST,PUT,DELETE"

new "restconf head"
expectfn "curl -sS -I http://localhost/restconf/data" "HTTP/1.1 200 OK"
#Content-Type: application/yang-data+json"

new "restconf root discovery"
expectfn "curl  -sS -X GET http://localhost/.well-known/host-meta" "<Link rel='restconf' href='/restconf'/>"

new "restconf empty rpc"
expectfn 'curl -sS -X POST -d {"input":{"name":""}} http://localhost/restconf/operations/ex:empty' '{"output": null}'

#new "restconf get restconf json XXX"
#expectfn "curl -sSG http://localhost/restconf" "{\"restconf\" : $state }"

#new "restconf get restconf/yang-library-version json XXX"
#expectfn "curl -sSG http://localhost/restconf/yang-library-version" "{\"restconf\" : $state }"

new "restconf get empty config + state json"
expectfn "curl -sSG http://localhost/restconf/data" "{\"data\": $state}"

new "restconf get empty config + state xml"
ret=$(curl -sS -H "Accept: application/yang-data+xml" -G http://localhost/restconf/data)
expect="<data><interfaces-state><interface><name>eth0</name><type>eth</type><if-index>42</if-index></interface></interfaces-state></data>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf get data/interfaces-state/interface=eth0 json"
expectfn "curl -sS -G http://localhost/restconf/data/interfaces-state/interface=eth0" '{"interface": {"name": "eth0","type": "eth","if-index": "42"}}'

new "restconf get state operation eth0 xml"
# Cant get shell macros to work, inline matching from lib.sh
ret=$(curl -sS -H "Accept: application/yang-data+xml" -G http://localhost/restconf/data/interfaces-state/interface=eth0)
expect="<interface><name>eth0</name><type>eth</type><if-index>42</if-index></interface>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf get state operation eth0 type json"
expectfn "curl -sS -G http://localhost/restconf/data/interfaces-state/interface=eth0/type" '{"type": "eth"}
$'

new "restconf get state operation eth0 type xml"
# Cant get shell macros to work, inline matching from lib.sh
ret=$(curl -sS -H "Accept: application/yang-data+xml" -G http://localhost/restconf/data/interfaces-state/interface=eth0/type)
expect="<type>eth</type>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf Add subtree  to datastore using POST"
expectfn 'curl -sS -X POST -d {"interfaces":{"interface":{"name":"eth/0/0","type":"eth","enabled":"true"}}} http://localhost/restconf/data' ""

new "restconf Check interfaces eth/0/0 added"
expectfn "curl -sS -G http://localhost/restconf/data" '{"interfaces": {"interface": {"name": "eth/0/0","type": "eth","enabled": "true"}},"interfaces-state": {"interface": {"name": "eth0","type": "eth","if-index": "42"}}}
$'

new "restconf delete interfaces"
expectfn 'curl -sS -X DELETE  http://localhost/restconf/data/interfaces' ""

new "restconf Check empty config"
expectfn "curl -sSG http://localhost/restconf/data" $state

new "restconf Add interfaces subtree eth/0/0 using POST"
expectfn 'curl -sS -X POST -d {"interface":{"name":"eth/0/0","type":"eth","enabled":"true"}} http://localhost/restconf/data/interfaces' ""

new "restconf Check eth/0/0 added"
expectfn "curl -sS -G http://localhost/restconf/data" '{"interfaces": {"interface": {"name": "eth/0/0","type": "eth","enabled": "true"}},"interfaces-state": {"interface": {"name": "eth0","type": "eth","if-index": "42"}}}
$'

new "restconf Re-post eth/0/0 which should generate error"
expectfn 'curl -sS -X POST -d {"interface":{"name":"eth/0/0","type":"eth","enabled":"true"}} http://localhost/restconf/data/interfaces' "Data resource already exists"

new "Add leaf description using POST"
expectfn 'curl -sS -X POST -d {"description":"The-first-interface"} http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0' ""

new "Add nothing using POST"
expectfn 'curl -sS -X POST http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0' "data is in some way badly formed"

new "restconf Check description added"
expectfn "curl -sS -G http://localhost/restconf/data" '{"interfaces": {"interface": {"name": "eth/0/0","description": "The-first-interface","type": "eth","enabled": "true"}}
$'

new "restconf delete eth/0/0"
expectfn 'curl -sS -X DELETE  http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0' ""

new "Check deleted eth/0/0"
expectfn 'curl -sS -G http://localhost/restconf/data' $state

new "restconf Re-Delete eth/0/0 using none should generate error"
expectfn 'curl -sS -X DELETE  http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0' "Not Found"

new "restconf Add subtree eth/0/0 using PUT"
expectfn 'curl -sS -X PUT -d {"interface":{"name":"eth/0/0","type":"eth","enabled":"true"}} http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0' ""

new "restconf get subtree"
expectfn "curl -sS -G http://localhost/restconf/data" '{"interfaces": {"interface": {"name": "eth/0/0","type": "eth","enabled": "true"}},"interfaces-state": {"interface": {"name": "eth0","type": "eth","if-index": "42"}}}
$'

new "restconf rpc using POST json"
expectfn 'curl -sS -X POST -d {"input":{"routing-instance-name":"ipv4"}} http://localhost/restconf/operations/rt:fib-route' '{"output": {"route": {"address-family": "ipv4","next-hop": {"next-hop-list": "2.3.4.5"}}}}'

new "restconf rpc using POST xml"
# Cant get shell macros to work, inline matching from lib.sh
ret=$(curl -sS -X POST -H "Accept: application/yang-data+xml" -d '{"input":{"routing-instance-name":"ipv4"}}' http://localhost/restconf/operations/rt:fib-route)
expect="<output><route><address-family>ipv4</address-family><next-hop><next-hop-list>2.3.4.5</next-hop-list></next-hop></route></output>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "Kill restconf daemon"
sudo pkill -u www-data clixon_restconf

new "Kill backend"
# Check if still alive
pid=`pgrep clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
