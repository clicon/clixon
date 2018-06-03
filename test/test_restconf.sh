#!/bin/bash
# Restconf basic functionality
# Assume http server setup, such as nginx described in apps/restconf/README.md
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh
cfg=$dir/conf.xml
fyang=$dir/restconf.yang

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/$APPNAME/yang</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>$fyang</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

cat <<EOF > $fyang
module example{
    prefix ex;
    import ietf-interfaces {
	prefix if;
    }
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
    identity eth {
	base if:interface-type;
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
    rpc client-rpc {
       	description "Example local client-side rpc";
	input {
	    leaf request {
		type string;
	    }
	}
	output {
	    leaf result{
		type string;
	    }
	}
    }
}
EOF

# This is a fixed 'state' implemented in routing_backend. It is assumed to be always there
state='{"interfaces-state": {"interface": \[{"name": "eth0","type": "ex:eth","if-index": 42}\]}}'

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err
fi
new "start backend -s init -f $cfg -y $fyang"
sudo clixon_backend -s init -f $cfg -y $fyang # -D 1
if [ $? -ne 0 ]; then
    err
fi

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
sudo start-stop-daemon -S -q -o -b -x /www-data/clixon_restconf -d /www-data -c www-data -- -f $cfg -y $fyang # -D

sleep 1

new "restconf tests"

new2 "restconf root discovery. RFC 8040 3.1 (xml+xrd)"
expecteq "$(curl  -s -X GET http://localhost/.well-known/host-meta)" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>
   <Link rel='restconf' href='/restconf'/>
</XRD>"

new2 "restconf get restconf resource. RFC 8040 3.3 (json)"
expecteq "$(curl -sG http://localhost/restconf)" '{"restconf": {"data": null,"operations": null,"yang-library-version": "2016-06-21"}}
'

new2 "restconf get restconf resource. RFC 8040 3.3 (xml)"
# Get XML instead of JSON?
expecteq "$(curl -s -H 'Accept: application/yang-data+xml' -G http://localhost/restconf)" '<restconf><data/><operations/><yang-library-version>2016-06-21</yang-library-version></restconf>
'

new2 "restconf get restconf/operations. RFC8040 3.3.2 (json)"
expecteq "$(curl -sG http://localhost/restconf/operations)" '{"operations": {"ex:empty": null,"ex:input": null,"ex:output": null,"ex:client-rpc": null,"rt:fib-route": null,"rt:route-count": null}}
'

new "restconf get restconf/operations. RFC8040 3.3.2 (xml)"
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/operations)
expect="<operations><ex:empty/><ex:input/><ex:output/><ex:client-rpc/><rt:fib-route/><rt:route-count/></operations>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new2 "restconf get restconf/yang-library-version. RFC8040 3.3.3"
expecteq "$(curl -sG http://localhost/restconf/yang-library-version)" '{"yang-library-version": "2016-06-21"}'

new "restconf get restconf/yang-library-version. RFC8040 3.3.3 (xml)"
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/yang-library-version)
expect="<yang-library-version>2016-06-21</yang-library-version>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf options. RFC 8040 4.1"
expectfn "curl -i -s -X OPTIONS http://localhost/restconf/data" 0 "Allow: OPTIONS,HEAD,GET,POST,PUT,DELETE"

new "restconf head. RFC 8040 4.2"
expectfn "curl -s -I http://localhost/restconf/data" 0 "HTTP/1.1 200 OK"
#Content-Type: application/yang-data+json"

new2 "restconf empty rpc"
expecteq "$(curl -s -X POST -d {\"input\":{\"name\":\"\"}} http://localhost/restconf/operations/ex:empty)" ""

new2 "restconf get empty config + state json"
expecteq "$(curl -sSG http://localhost/restconf/data)" '{"data": {"interfaces-state": {"interface": [{"name": "eth0","type": "ex:eth","if-index": 42}]}}}
'

new "restconf get empty config + state xml"
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/data)
expect="<data><interfaces-state><interface><name>eth0</name><type>ex:eth</type><if-index>42</if-index></interface></interfaces-state></data>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new2 "restconf get data/interfaces-state/interface=eth0 json"
expecteq "$(curl -s -G http://localhost/restconf/data/interfaces-state/interface=eth0)" '{"interface": [{"name": "eth0","type": "ex:eth","if-index": 42}]}
'

new "restconf get state operation eth0 xml"
# Cant get shell macros to work, inline matching from lib.sh
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/data/interfaces-state/interface=eth0)
expect="<interface><name>eth0</name><type>ex:eth</type><if-index>42</if-index></interface>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new2 "restconf get state operation eth0 type json"
expecteq "$(curl -s -G http://localhost/restconf/data/interfaces-state/interface=eth0/type)" '{"type": "ex:eth"}
'

new "restconf get state operation eth0 type xml"
# Cant get shell macros to work, inline matching from lib.sh
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/data/interfaces-state/interface=eth0/type)
expect="<type>ex:eth</type>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new2 "restconf GET datastore"
expecteq "$(curl -s -X GET http://localhost/restconf/data)" '{"data": {"interfaces-state": {"interface": [{"name": "eth0","type": "ex:eth","if-index": 42}]}}}
'

# Exact match
new "restconf Add subtree to datastore using POST"
expectfn 'curl -s -i -X POST -H "Accept: application/yang-data+json" -d {"interfaces":{"interface":{"name":"eth/0/0","type":"ex:eth","enabled":true}}} http://localhost/restconf/data' 0 'HTTP/1.1 200 OK'

new "restconf Re-add subtree which should give error"
expectfn 'curl -s -X POST -d {"interfaces":{"interface":{"name":"eth/0/0","type":"ex:eth","enabled":true}}} http://localhost/restconf/data' 0 '{"ietf-restconf:errors" : {"error": {"error-tag": "data-exists","error-type": "application","error-severity": "error","error-message": "Data already exists; cannot create new resource"}}}'

# XXX Cant get this to work
#expecteq "$(curl -s -X POST -d {\"interfaces\":{\"interface\":{\"name\":\"eth/0/0\",\"type\":\"ex:eth\",\"enabled\":true}}} http://localhost/restconf/data)" '{"ietf-restconf:errors" : {"error": {"error-tag": "data-exists","error-type": "application","error-severity": "error","error-message": "Data already exists; cannot create new resource"}}}'

new "restconf Check interfaces eth/0/0 added"
expectfn "curl -s -G http://localhost/restconf/data" 0 '{"interfaces": {"interface": \[{"name": "eth/0/0","type": "ex:eth","enabled": true}\]},"interfaces-state": {"interface": \[{"name": "eth0","type": "ex:eth","if-index": 42}\]}}
'

new2 "restconf delete interfaces"
expecteq $(curl -s -X DELETE  http://localhost/restconf/data/interfaces) ""

new "restconf Check empty config"
expectfn "curl -sG http://localhost/restconf/data" 0 "$state"

new "restconf Add interfaces subtree eth/0/0 using POST"
expectfn 'curl -s -X POST -d {"interface":{"name":"eth/0/0","type":"ex:eth","enabled":true}} http://localhost/restconf/data/interfaces' 0 ""
# XXX cant get this to work
#expecteq "$(curl -s -X POST -d '{"interface":{"name":"eth/0/0","type\":"ex:eth","enabled":true}}' http://localhost/restconf/data/interfaces)" ""

new2 "restconf Check eth/0/0 added"
expecteq "$(curl -s -G http://localhost/restconf/data)" '{"data": {"interfaces": {"interface": [{"name": "eth/0/0","type": "ex:eth","enabled": true}]},"interfaces-state": {"interface": [{"name": "eth0","type": "ex:eth","if-index": 42}]}}}
'

new2 "restconf Re-post eth/0/0 which should generate error"
expecteq "$(curl -s -X POST -d '{"interface":{"name":"eth/0/0","type":"ex:eth","enabled":true}}' http://localhost/restconf/data/interfaces)" '{"ietf-restconf:errors" : {"error": {"error-tag": "data-exists","error-type": "application","error-severity": "error","error-message": "Data already exists; cannot create new resource"}}}'

new "Add leaf description using POST"
expecteq "$(curl -s -X POST -d '{"description":"The-first-interface"}' http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0)" ""

new "Add nothing using POST"
expectfn 'curl -s -X POST http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0' 0 '"ietf-restconf:errors" : {"error": {"rpc-error": {"error-tag": "malformed-message","error-type": "rpc","error-severity": "error","error-message": " on line 1: syntax error at or before:'

new2 "restconf Check description added"
expecteq "$(curl -s -G http://localhost/restconf/data)" '{"data": {"interfaces": {"interface": [{"name": "eth/0/0","description": "The-first-interface","type": "ex:eth","enabled": true}]},"interfaces-state": {"interface": [{"name": "eth0","type": "ex:eth","if-index": 42}]}}}
'

new "restconf delete eth/0/0"
expecteq "$(curl -s -X DELETE  http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0)" ""

new "Check deleted eth/0/0"
expectfn 'curl -s -G http://localhost/restconf/data' 0 $state

new2 "restconf Re-Delete eth/0/0 using none should generate error"
expecteq "$(curl -s -X DELETE  http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0)" '{"ietf-restconf:errors" : {"error": {"error-tag": "data-missing","error-type": "application","error-severity": "error","error-message": "Data does not exist; cannot delete resource"}}}'

new "restconf Add subtree eth/0/0 using PUT"
expecteq "$(curl -s -X PUT -d '{"interface":{"name":"eth/0/0","type":"ex:eth","enabled":true}}' http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0)" ""

new2 "restconf get subtree"
expecteq "$(curl -s -G http://localhost/restconf/data)" '{"data": {"interfaces": {"interface": [{"name": "eth/0/0","type": "ex:eth","enabled": true}]},"interfaces-state": {"interface": [{"name": "eth0","type": "ex:eth","if-index": 42}]}}}
'

new2 "restconf rpc using POST json"
expecteq "$(curl -s -X POST -d '{"input":{"routing-instance-name":"ipv4"}}' http://localhost/restconf/operations/rt:fib-route)" '{"output": {"route": {"address-family": "ipv4","next-hop": {"next-hop-list": "2.3.4.5"}}}}
'

# Cant get this to work due to quoting
#new2 "restconf rpc using POST wrong JSON"
#expecteq "$(curl -s -X POST -d '{"input":{"routing-instance-name":ipv4}}' http://localhost/restconf/operations/rt:fib-route)" '{"ietf-restconf:errors" : {"error": {"rpc-error": {"error-tag": "operation-failed","error-type": "protocol","error-severity": "error","error-message": " on line 1: syntax error at or before: i"}}}}'

new2 "restconf rpc using POST json w/o mandatory element"
expecteq "$(curl -s -X POST -d '{"input":{"wrongelement":"ipv4"}}' http://localhost/restconf/operations/rt:fib-route)" '{"ietf-restconf:errors" : {"error": {"rpc-error": {"error-tag": "operation-failed","error-type": "protocol","error-severity": "error","error-message": "Missing mandatory variable: routing-instance-name"}}}}'
new2 "restconf rpc non-existing rpc w/o namespace"
expecteq "$(curl -s -X POST -d '{}' http://localhost/restconf/operations/kalle)" '{"ietf-restconf:errors" : {"error": {"rpc-error": {"error-tag": "operation-failed","error-type": "protocol","error-severity": "error","error-message": "yang node not found"}}}}'

new2 "restconf rpc non-existing rpc"
expecteq "$(curl -s -X POST -d '{}' http://localhost/restconf/operations/ex:kalle)" '{"ietf-restconf:errors" : {"error": {"rpc-error": {"error-tag": "operation-failed","error-type": "protocol","error-severity": "error","error-message": "yang node not found"}}}}'

new2 "restconf rpc missing name"
expecteq "$(curl -s -X POST -d '{}' http://localhost/restconf/operations)" '{"ietf-restconf:errors" : {"error": {"rpc-error": {"error-tag": "operation-failed","error-type": "protocol","error-severity": "error","error-message": "Operation name expected"}}}}'

new2 "restconf rpc missing input"
expecteq "$(curl -s -X POST -d '{}' http://localhost/restconf/operations/rt:fib-route)" '{"ietf-restconf:errors" : {"error": {"rpc-error": {"error-tag": "operation-failed","error-type": "protocol","error-severity": "error","error-message": "Missing mandatory variable: routing-instance-name"}}}}'

new "restconf rpc using POST xml"
ret=$(curl -s -X POST -H "Accept: application/yang-data+xml" -d '{"input":{"routing-instance-name":"ipv4"}}' http://localhost/restconf/operations/rt:fib-route)
expect="<output><route><address-family>ipv4</address-family><next-hop><next-hop-list>2.3.4.5</next-hop-list></next-hop></route></output>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf local client rpc using POST xml"
ret=$(curl -s -X POST -H "Accept: application/yang-data+xml" -d '{"input":{"request":"example"}}' http://localhost/restconf/operations/ex:client-rpc)
expect="<output><result>ok</result></output>"
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

# XXX cant get -H to work
#expecteq 'curl -s -X POST -H "Accept: application/yang-data+xml" -d {"input":{"routing-instance-name":"ipv4"}} http://localhost/restconf/operations/rt:fib-route' '<output><route><address-family>ipv4</address-family><next-hop><next-hop-list>2.3.4.5</next-hop-list></next-hop></route></output>'

# Cant get shell macros to work, inline matching from lib.sh


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
