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
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

# This is a fixed 'state' implemented in routing_backend. It is assumed to be always there
state='{"clixon-example:state":{"op":\["41","42","43"\]}'

new "test params: -f $cfg -- -s"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure

    new "start backend -s init -f $cfg -- -s"
    start_backend -s init -f $cfg -- -s
fi

new "waiting"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg

fi
new "waiting"
wait_restconf

new "restconf root discovery. RFC 8040 3.1 (xml+xrd)"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/.well-known/host-meta)" 0 'HTTP/1.1 200 OK' "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"

new "restconf get restconf resource. RFC 8040 3.3 (json)"
expectpart "$(curl -sik -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf)" 0 'HTTP/1.1 200 OK' '{"ietf-restconf:restconf":{"data":{},"operations":{},"yang-library-version":"2016-06-21"}}'

new "restconf get restconf resource. RFC 8040 3.3 (xml)"
# Get XML instead of JSON?
expectpart "$(curl -sik -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf)" 0 'HTTP/1.1 200 OK' '<restconf xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><data/><operations/><yang-library-version>2016-06-21</yang-library-version></restconf>'

# Should be alphabetically ordered
new "restconf get restconf/operations. RFC8040 3.3.2 (json)"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/operations)" 0 'HTTP/1.1 200 OK' '{"operations":{"clixon-example:client-rpc":\[null\],"clixon-example:empty":\[null\],"clixon-example:optional":\[null\],"clixon-example:example":\[null\],"clixon-lib:debug":\[null\],"clixon-lib:ping":\[null\],"clixon-lib:stats":\[null\],"clixon-lib:restart-plugin":\[null\],"ietf-netconf:get-config":\[null\],"ietf-netconf:edit-config":\[null\],"ietf-netconf:copy-config":\[null\],"ietf-netconf:delete-config":\[null\],"ietf-netconf:lock":\[null\],"ietf-netconf:unlock":\[null\],"ietf-netconf:get":\[null\],"ietf-netconf:close-session":\[null\],"ietf-netconf:kill-session":\[null\],"ietf-netconf:commit":\[null\],"ietf-netconf:discard-changes":\[null\],"ietf-netconf:validate":\[null\]}}'

new "restconf get restconf/operations. RFC8040 3.3.2 (xml)"
ret=$(curl -sik -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/operations)
expect='<operations><client-rpc xmlns="urn:example:clixon"/><empty xmlns="urn:example:clixon"/><optional xmlns="urn:example:clixon"/><example xmlns="urn:example:clixon"/><debug xmlns="http://clicon.org/lib"/><ping xmlns="http://clicon.org/lib"/><stats xmlns="http://clicon.org/lib"/><restart-plugin xmlns="http://clicon.org/lib"/><get-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><edit-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><copy-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><delete-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><lock xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><unlock xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><get xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><close-session xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><kill-session xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><commit xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><discard-changes xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/><validate xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"/></operations>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf get restconf/yang-library-version. RFC8040 3.3.3"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/yang-library-version)" 0 'HTTP/1.1 200 OK' '{"yang-library-version":"2016-06-21"}'

new "restconf get restconf/yang-library-version. RFC8040 3.3.3 (xml)"
ret=$(curl -sik -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/yang-library-version)
expect="<yang-library-version>2016-06-21</yang-library-version>"
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf schema resource, RFC 8040 sec 3.7 according to RFC 7895 (explicit resource)"
expectpart "$(curl -sik -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/ietf-yang-library:modules-state/module=ietf-interfaces,2018-02-20)" 0 'HTTP/1.1 200 OK' '{"ietf-yang-library:module":\[{"name":"ietf-interfaces","revision":"2018-02-20","namespace":"urn:ietf:params:xml:ns:yang:ietf-interfaces","conformance-type":"implement"}\]}'

new "restconf options. RFC 8040 4.1"
expectpart "$(curl -sik -X OPTIONS $RCPROTO://localhost/restconf/data)" 0 "HTTP/1.1 200 OK" "Allow: OPTIONS,HEAD,GET,POST,PUT,PATCH,DELETE"

# -I means HEAD
new "restconf HEAD. RFC 8040 4.2"
expectpart "$(curl -sik -I -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data)" 0 "HTTP/1.1 200 OK" "Content-Type: application/yang-data+json"

new "restconf empty rpc JSON"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d {\"clixon-example:input\":null} $RCPROTO://localhost/restconf/operations/clixon-example:empty)" 0  "HTTP/1.1 204 No Content"

new "restconf empty rpc XML"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+xml" -d '<input xmlns="urn:example:clixon"></input>' $RCPROTO://localhost/restconf/operations/clixon-example:empty)" 0  "HTTP/1.1 204 No Content"

new "restconf empty rpc, default media type should fail"
expectpart "$(curl -sik -X POST -d {\"clixon-example:input\":null} $RCPROTO://localhost/restconf/operations/clixon-example:empty)" 0 'HTTP/1.1 415 Unsupported Media Type'

new "restconf empty rpc, default media type should fail (JSON)"
expectpart "$(curl -sik -X POST -H "Accept: application/yang-data+json" -d {\"clixon-example:input\":null} $RCPROTO://localhost/restconf/operations/clixon-example:empty)" 0 'HTTP/1.1 415 Unsupported Media Type'

new "restconf empty rpc with extra args (should fail)"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d {\"clixon-example:input\":{\"extra\":null}} $RCPROTO://localhost/restconf/operations/clixon-example:empty)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"extra"},"error-severity":"error","error-message":"Unrecognized parameter: extra in rpc: empty"}}}'

# Irritiating to get debugs on the terminal
#new "restconf debug rpc"
#expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d {\"clixon-lib:input\":{\"level\":0}} $RCPROTO://localhost/restconf/operations/clixon-lib:debug)" 0  "HTTP/1.1 204 No Content"

new "restconf get empty config + state json"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/clixon-example:state)" 0 "HTTP/1.1 200 OK" '{"clixon-example:state":{"op":\["41","42","43"\]}}'

new "restconf get empty config + state json with wrong module name"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/badmodule:state)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"badmodule"},"error-severity":"error","error-message":"No such yang module prefix"}}}'

#'HTTP/1.1 404 Not Found'
#'{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"No such yang module: badmodule"}}}'

new "restconf get empty config + state xml"
ret=$(curl -sik -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data/clixon-example:state)
expect='<state xmlns="urn:example:clixon"><op>41</op><op>42</op><op>43</op></state>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf get data type json"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/clixon-example:state/op=42)" 0 '{"clixon-example:op":"42"}'

new "restconf get state operation"
# Cant get shell macros to work, inline matching from lib.sh
ret=$(curl -sik -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data/clixon-example:state/op=42)
expect='<op xmlns="urn:example:clixon">42</op>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf get state operation type json"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/clixon-example:state/op=42)" 0 '{"clixon-example:op":"42"}'

new "restconf get state operation type xml"
# Cant get shell macros to work, inline matching from lib.sh
ret=$(curl -sik -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data/clixon-example:state/op=42)
expect='<op xmlns="urn:example:clixon">42</op>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf GET datastore"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/clixon-example:state)" 0 "HTTP/1.1 200 OK" '{"clixon-example:state":{"op":\["41","42","43"\]}}'

# Exact match
new "restconf Add subtree eth/0/0 to datastore using POST"
expectpart "$(curl -sik -X POST -H "Accept: application/yang-data+json" -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interfaces":{"interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}}' $RCPROTO://localhost/restconf/data)" 0 'HTTP/1.1 201 Created' "Location: $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces"

new "restconf Re-add subtree eth/0/0 which should give error"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interfaces":{"interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}}' $RCPROTO://localhost/restconf/data)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-exists","error-severity":"error","error-message":"Data already exists; cannot create new resource"}}}'

new "restconf Check interfaces eth/0/0 added"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/1.1 200 OK" '{"ietf-interfaces:interfaces":{"interface":\[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}\]}}'

new "restconf delete interfaces"
expectpart "$(curl -sik -X DELETE $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/1.1 204 No Content"

new "restconf Check empty config"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/clixon-example:state)" 0 "HTTP/1.1 200 OK" "$state"

new "restconf Add interfaces subtree eth/0/0 using POST"
expectpart "$(curl -sik -X POST $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}')" 0 "HTTP/1.1 201 Created"

new "restconf Check eth/0/0 added config"
expectpart "$(curl -sik -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 'HTTP/1.1 200 OK' '{"ietf-interfaces:interfaces":{"interface":\[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}\]}}'

new "restconf Check eth/0/0 GET augmented state level 1"
expectpart "$(curl -sik -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 'HTTP/1.1 200 OK' '{"ietf-interfaces:interface":\[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}\]}'

new "restconf Check eth/0/0 GET augmented state level 2"
expectpart "$(curl -sik -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0/clixon-example:my-status)" 0 'HTTP/1.1 200 OK' '{"clixon-example:my-status":{"int":42,"str":"foo"}}' 

new "restconf Check eth/0/0 added state XXXXXXX"
expectpart "$(curl -sik -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/clixon-example:state)" 0 'HTTP/1.1 200 OK' '{"clixon-example:state":{"op":\["41","42","43"\]}}'

new "restconf Re-post eth/0/0 which should generate error"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-exists","error-severity":"error","error-message":"Data already exists; cannot create new resource"}}}'

new "Add leaf description using POST"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:description":"The-first-interface"}' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 "HTTP/1.1 201 Created"

new "Add nothing using POST (expect fail)"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0  'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"The message-body MUST contain exactly one instance of the expected data resource"}}}'

new "restconf Check description added"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/1.1 200 OK" '{"ietf-interfaces:interfaces":{"interface":\[{"name":"eth/0/0","description":"The-first-interface","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}\]}}'

new "restconf delete eth/0/0"
expectpart "$(curl -sik -X DELETE $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 "HTTP/1.1 204 No Content"

new "Check deleted eth/0/0"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data)" 0 "HTTP/1.1 200 OK" "$state"

new "restconf Re-Delete eth/0/0 using none should generate error"
expectpart "$(curl -sik -X DELETE $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 "HTTP/1.1 409 Conflict" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-missing","error-severity":"error","error-message":"Data does not exist; cannot delete resource"}}}'

new "restconf Add subtree eth/0/0 using PUT"
expectpart "$(curl -sik -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 "HTTP/1.1 201 Created"

new "restconf get subtree"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/1.1 200 OK" '{"ietf-interfaces:interfaces":{"interface":\[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}\]}}'

new "restconf rpc using POST json"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":42}}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 "HTTP/1.1 200 OK" '{"clixon-example:output":{"x":"42","y":"42"}}'

if ! $YANG_UNKNOWN_ANYDATA ; then
new "restconf rpc using POST json wrong"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"wrongelement":"ipv4"}}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"bad-element","error-info":{"bad-element":"wrongelement"},"error-severity":"error","error-message":"Failed to find YANG spec of XML node: wrongelement with parent: example in namespace: urn:example:clixon"}}}'
fi

new "restconf rpc non-existing rpc without namespace"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d '{}' $RCPROTO://localhost/restconf/operations/kalle)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"missing-element","error-info":{"bad-element":"kalle"},"error-severity":"error","error-message":"RPC not defined"}}'

new "restconf rpc non-existing rpc"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d '{}' $RCPROTO://localhost/restconf/operations/clixon-example:kalle)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"missing-element","error-info":{"bad-element":"kalle"},"error-severity":"error","error-message":"RPC not defined"}}'

new "restconf rpc missing name"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d '{}' $RCPROTO://localhost/restconf/operations)" 0 'HTTP/1.1 412 Precondition Failed' '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"Operation name expected"}}}'

new "restconf rpc missing input"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d '{}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"restconf RPC does not have input statement"}}}'

new "restconf rpc using POST xml"
ret=$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -H "Accept: application/yang-data+xml" -d '{"clixon-example:input":{"x":42}}' $RCPROTO://localhost/restconf/operations/clixon-example:example)
expect='<output xmlns="urn:example:clixon"><x>42</x><y>42</y></output>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf rpc using wrong prefix"
expectpart "$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -d '{"wrong:input":{"routing-instance-name":"ipv4"}}' $RCPROTO://localhost/restconf/operations/wrong:example)" 0 "HTTP/1.1 412 Precondition Failed" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"yang module not found"}}}'

new "restconf local client rpc using POST xml"
ret=$(curl -sik -X POST -H "Content-Type: application/yang-data+json" -H "Accept: application/yang-data+xml" -d '{"clixon-example:input":{"x":"example"}}' $RCPROTO://localhost/restconf/operations/clixon-example:client-rpc)
expect='<output xmlns="urn:example:clixon"><x>example</x></output>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf Add subtree without key (expected error)"
expectpart "$(curl -sik -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"malformed key =interface, expected'

new "restconf Add subtree with too many keys (expected error)"
expectpart "$(curl -sik -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=a,b)" 0 "HTTP/1.1 400 Bad Request" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"List key interface length mismatch"}}}'

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
