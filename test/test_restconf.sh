#!/usr/bin/env bash
# Restconf basic functionality
# also uri encoding using eth/0/0
# Assume http server setup, such as nginx described in apps/restconf/README.md

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
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
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

# This is a fixed 'state' implemented in routing_backend. It is assumed to be always there
state='{"clixon-example:state":{"op":\["42","41","43"\]}'

new "test params: -f $cfg -- -s"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill clixon_backend # to be sure
    new "start backend -s init -f $cfg -- -s"
    start_backend -s init -f $cfg -- -s
fi

new "kill old restconf daemon"
sudo pkill -u $wwwuser clixon_restconf

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

new "restconf root discovery. RFC 8040 3.1 (xml+xrd)"
expecteq "$(curl -s -X GET http://localhost/.well-known/host-meta)" 0 "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>
   <Link rel='restconf' href='/restconf'/>
</XRD>"

new "restconf get restconf resource. RFC 8040 3.3 (json)"
expecteq "$(curl -sG -H "Accept: application/yang-data+json" http://localhost/restconf)" 0 '{"ietf-restconf:restconf":{"data":{},"operations":{},"yang-library-version":"2016-06-21"}}
'

new "restconf get restconf resource. RFC 8040 3.3 (xml)"
# Get XML instead of JSON?
expecteq "$(curl -s -H 'Accept: application/yang-data+xml' -G http://localhost/restconf)" 0 '<restconf xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><data/><operations/><yang-library-version>2016-06-21</yang-library-version></restconf>
'

# Should be alphabetically ordered
new "restconf get restconf/operations. RFC8040 3.3.2 (json)"
expecteq "$(curl -sG http://localhost/restconf/operations)" 0 '{"operations":{"clixon-example:client-rpc":[null],"clixon-example:empty":[null],"clixon-example:optional":[null],"clixon-example:example":[null],"clixon-lib:debug":[null],"clixon-lib:ping":[null],"ietf-netconf:get-config":[null],"ietf-netconf:edit-config":[null],"ietf-netconf:copy-config":[null],"ietf-netconf:delete-config":[null],"ietf-netconf:lock":[null],"ietf-netconf:unlock":[null],"ietf-netconf:get":[null],"ietf-netconf:close-session":[null],"ietf-netconf:kill-session":[null],"ietf-netconf:commit":[null],"ietf-netconf:discard-changes":[null],"ietf-netconf:validate":[null],"clixon-rfc5277:create-subscription":[null]}}
'

new "restconf get restconf/operations. RFC8040 3.3.2 (xml)"
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/operations)
expect='<operations><client-rpc xmlns="urn:example:clixon"/><empty xmlns="urn:example:clixon"/><optional xmlns="urn:example:clixon"/><example xmlns="urn:example:clixon"/><debug xmlns="http://clicon.org/lib"/><ping xmlns="http://clicon.org/lib"/><get-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><edit-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><copy-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><delete-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><lock xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><unlock xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><get xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><close-session xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><kill-session xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><commit xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><discard-changes xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><validate xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><create-subscription xmlns="urn:ietf:params:xml:ns:netmod:notification"/></operations>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf get restconf/yang-library-version. RFC8040 3.3.3"
expecteq "$(curl -sG http://localhost/restconf/yang-library-version)" 0 '{"yang-library-version":"2016-06-21"}'

new "restconf get restconf/yang-library-version. RFC8040 3.3.3 (xml)"
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/yang-library-version)
expect="<yang-library-version>2016-06-21</yang-library-version>"
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf schema resource, RFC 8040 sec 3.7 according to RFC 7895 (explicit resource)"
expecteq "$(curl -s -H 'Accept: application/yang-data+json' -G http://localhost/restconf/data/ietf-yang-library:modules-state/module=ietf-interfaces,2018-02-20)" 0 '{"ietf-yang-library:module":[{"name":"ietf-interfaces","revision":"2018-02-20","namespace":"urn:ietf:params:xml:ns:yang:ietf-interfaces","conformance-type":"implement"}]}
'

new "restconf options. RFC 8040 4.1"
expectpart "$(curl -is -X OPTIONS http://localhost/restconf/data)" 0 "HTTP/1.1 200 OK" "Allow: OPTIONS,HEAD,GET,POST,PUT,PATCH,DELETE"

# -I means HEAD
new "restconf HEAD. RFC 8040 4.2"
expectpart "$(curl -si -I -H "Accept: application/yang-data+json" http://localhost/restconf/data)" 0 "HTTP/1.1 200 OK" "Content-Type: application/yang-data+json"

new "restconf empty rpc"
expectpart "$(curl -si -X POST -H "Content-Type: application/yang-data+json" -d {\"clixon-example:input\":null} http://localhost/restconf/operations/clixon-example:empty)" 0  "HTTP/1.1 204 No Content"

new "restconf empty rpc, default media type should fail"
expectpart "$(curl -si -X POST -d {\"clixon-example:input\":null} http://localhost/restconf/operations/clixon-example:empty)" 0 'HTTP/1.1 415 Unsupported Media Type'

new "restconf empty rpc, default media type should fail (JSON)"
expectpart "$(curl -si -X POST -H "Accept: application/yang-data+json" -d {\"clixon-example:input\":null} http://localhost/restconf/operations/clixon-example:empty)" 0 'HTTP/1.1 415 Unsupported Media Type'

new "restconf empty rpc with extra args (should fail)"
expectpart "$(curl -si -X POST -H "Content-Type: application/yang-data+json" -d {\"clixon-example:input\":{\"extra\":null}} http://localhost/restconf/operations/clixon-example:empty)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"extra"},"error-severity":"error"}}}'

new "restconf debug rpc"
expectpart "$(curl -si -X POST -H "Content-Type: application/yang-data+json" -d {\"clixon-lib:input\":{\"level\":0}} http://localhost/restconf/operations/clixon-lib:debug)" 0  "HTTP/1.1 204 No Content"

new "restconf get empty config + state json"
expecteq "$(curl -sS -X GET http://localhost/restconf/data/clixon-example:state)" 0 '{"clixon-example:state":{"op":["42","41","43"]}}
'

new "restconf get empty config + state json with wrong module name"
expectpart "$(curl -siSG http://localhost/restconf/data/badmodule:state)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"No such yang module: badmodule"}}}'

new "restconf get empty config + state xml"
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/data/clixon-example:state)
expect='<state xmlns="urn:example:clixon"><op>42</op><op>41</op><op>43</op></state>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf get data type json"
expecteq "$(curl -s -G http://localhost/restconf/data/clixon-example:state/op=42)" 0 '{"clixon-example:op":"42"}
'

new "restconf get state operation"
# Cant get shell macros to work, inline matching from lib.sh
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/data/clixon-example:state/op=42)
expect='<op xmlns="urn:example:clixon">42</op>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf get state operation type json"
expecteq "$(curl -s -G http://localhost/restconf/data/clixon-example:state/op=42)" 0 '{"clixon-example:op":"42"}
'

new "restconf get state operation type xml"
# Cant get shell macros to work, inline matching from lib.sh
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/data/clixon-example:state/op=42)
expect='<op xmlns="urn:example:clixon">42</op>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf GET datastore"
expecteq "$(curl -s -X GET http://localhost/restconf/data/clixon-example:state)" 0 '{"clixon-example:state":{"op":["42","41","43"]}}
'

# Exact match
new "restconf Add subtree eth/0/0 to datastore using POST"
expectpart "$(curl -s -i -X POST -H "Accept: application/yang-data+json" -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interfaces":{"interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}}' http://localhost/restconf/data)" 0 'HTTP/1.1 201 Created' 'Location: http://localhost/restconf/data/ietf-interfaces:interfaces'

new "restconf Re-add subtree eth/0/0 which should give error"
expectpart "$(curl -s -X POST -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interfaces":{"interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}}' http://localhost/restconf/data)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-exists","error-severity":"error","error-message":"Data already exists; cannot create new resource"}}}'

# XXX Cant get this to work
#expecteq "$(curl -s -X POST -d {\"interfaces\":{\"interface\":{\"name\":\"eth/0/0\",\"type\":\"clixon-example:eth\",\"enabled\":true}}} http://localhost/restconf/data)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-exists","error-severity":"error","error-message":"Data already exists; cannot create new resource"}}}'

new "restconf Check interfaces eth/0/0 added"
expectfn "curl -s -X GET http://localhost/restconf/data/ietf-interfaces:interfaces" 0 '{"ietf-interfaces:interfaces":{"interface":\[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up"}\]}}}
'

new "restconf delete interfaces"
expecteq "$(curl -s -X DELETE  http://localhost/restconf/data/ietf-interfaces:interfaces)" 0 ""

new "restconf Check empty config"
expectfn "curl -sG http://localhost/restconf/data/clixon-example:state" 0 "$state
"

new "restconf Add interfaces subtree eth/0/0 using POST"
expectpart "$(curl -s -X POST http://localhost/restconf/data/ietf-interfaces:interfaces -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}')" 0 ""

new "restconf Check eth/0/0 added config"
expectpart "$(curl -s -X GET -H 'Accept: application/yang-data+json' http://localhost/restconf/data/ietf-interfaces:interfaces)" 0 '{"ietf-interfaces:interfaces":{"interface":\[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up"}\]}}
'

new "restconf Check eth/0/0 added state"
expectpart "$(curl -s -X GET -H 'Accept: application/yang-data+json' http://localhost/restconf/data/clixon-example:state)" 0 '{"clixon-example:state":{"op":\["42","41","43"\]}}
'

new "restconf Re-post eth/0/0 which should generate error"
expectpart "$(curl -s -X POST -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' http://localhost/restconf/data/ietf-interfaces:interfaces)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-exists","error-severity":"error","error-message":"Data already exists; cannot create new resource"}}}'

new "Add leaf description using POST"
expecteq "$(curl -s -X POST -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:description":"The-first-interface"}' http://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 ""

new "Add nothing using POST (expect fail)"
expectpart "$(curl -is -X POST -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0  'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"The message-body MUST contain exactly one instance of the expected data resource"}}}'

new "restconf Check description added"
expecteq "$(curl -s -G http://localhost/restconf/data/ietf-interfaces:interfaces)" 0 '{"ietf-interfaces:interfaces":{"interface":[{"name":"eth/0/0","description":"The-first-interface","type":"clixon-example:eth","enabled":true,"oper-status":"up"}]}}
'

new "restconf delete eth/0/0"
expecteq "$(curl -s -X DELETE  http://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 ""

new "Check deleted eth/0/0"
expectfn 'curl -s -G http://localhost/restconf/data' 0 "$state"

new "restconf Re-Delete eth/0/0 using none should generate error"
expecteq "$(curl -s -X DELETE  http://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-missing","error-severity":"error","error-message":"Data does not exist; cannot delete resource"}}}'

new "restconf Add subtree eth/0/0 using PUT"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' http://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 ""

new "restconf get subtree"
expecteq "$(curl -s -G http://localhost/restconf/data/ietf-interfaces:interfaces)" 0 '{"ietf-interfaces:interfaces":{"interface":[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up"}]}}
'

new "restconf rpc using POST json"
expecteq "$(curl -s -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":42}}' http://localhost/restconf/operations/clixon-example:example)" 0 '{"clixon-example:output":{"x":"42","y":"42"}}
'

new "restconf rpc using POST json wrong"
expecteq "$(curl -s -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"wrongelement":"ipv4"}}' http://localhost/restconf/operations/clixon-example:example)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"wrongelement"},"error-severity":"error"}}}'

new "restconf rpc non-existing rpc without namespace"
expecteq "$(curl -s -X POST -H "Content-Type: application/yang-data+json" -d '{}' http://localhost/restconf/operations/kalle)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"missing-element","error-info":{"bad-element":"kalle"},"error-severity":"error","error-message":"RPC not defined"}}}'

new "restconf rpc non-existing rpc"
expecteq "$(curl -s -X POST -H "Content-Type: application/yang-data+json" -d '{}' http://localhost/restconf/operations/clixon-example:kalle)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"missing-element","error-info":{"bad-element":"kalle"},"error-severity":"error","error-message":"RPC not defined"}}}'

new "restconf rpc missing name"
expecteq "$(curl -s -X POST -H "Content-Type: application/yang-data+json" -d '{}' http://localhost/restconf/operations)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"Operation name expected"}}}'

new "restconf rpc missing input"
expecteq "$(curl -s -X POST -H "Content-Type: application/yang-data+json" -d '{}' http://localhost/restconf/operations/clixon-example:example)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"restconf RPC does not have input statement"}}}'

new "restconf rpc using POST xml"
ret=$(curl -s -X POST -H "Content-Type: application/yang-data+json" -H "Accept: application/yang-data+xml" -d '{"clixon-example:input":{"x":42}}' http://localhost/restconf/operations/clixon-example:example)
expect='<output xmlns="urn:example:clixon"><x>42</x><y>42</y></output>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf rpc using wrong prefix"
expecteq "$(curl -s -X POST -H "Content-Type: application/yang-data+json" -d '{"wrong:input":{"routing-instance-name":"ipv4"}}' http://localhost/restconf/operations/wrong:example)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"yang module not found"}}}'

new "restconf local client rpc using POST xml"
ret=$(curl -s -i -X POST -H "Content-Type: application/yang-data+json" -H "Accept: application/yang-data+xml" -d '{"clixon-example:input":{"x":"example"}}' http://localhost/restconf/operations/clixon-example:client-rpc)
expect='<output xmlns="urn:example:clixon"><x>example</x></output>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf Add subtree without key (expected error)"
expectpart "$(curl -is -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' http://localhost/restconf/data/ietf-interfaces:interfaces/interface)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"malformed key =interface, expected'

new "restconf Add subtree with too many keys (expected error)"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' http://localhost/restconf/data/ietf-interfaces:interfaces/interface=a,b)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"List key interface length mismatch"}}}'

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
