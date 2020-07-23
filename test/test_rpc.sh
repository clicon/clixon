#!/usr/bin/env bash
# RPC tests
# Validate parameters in restconf and netconf, check namespaces, etc
# See rfc8040 3.6
# Use the example application that has one mandatory input arg,
# At the end is an alternative Yang without mandatory arg for
# valid empty input and output.

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
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "waiting"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg

    new "waiting"
    wait_restconf
fi

new "rpc tests"

# 1.First some positive tests vary media types
# extra complex because pattern matching on return haders
new "restconf empty rpc"
ret=$(curl $CURLOPTS -X POST $RCPROTO://localhost/restconf/operations/clixon-example:empty)
expect="204 No Content"
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "netconf empty rpc"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><empty xmlns="urn:example:clixon"/></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><ok/></rpc-reply>]]>]]>$'

new "restconf example rpc json/json default - no http media headers"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":0}}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'HTTP/1.1 200 OK' 'Content-Type: application/yang-data+json' '{"clixon-example:output":{"x":"0","y":"42"}}'

new "restconf example rpc json/json change y default"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":"0","y":"99"}}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'Content-Type: application/yang-data+json' '{"clixon-example:output":{"x":"0","y":"99"}}'

new "restconf example rpc json/json"
# XXX example:input example:output
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' -H 'Accept: application/yang-data+json' -d '{"clixon-example:input":{"x":"0"}}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'Content-Type: application/yang-data+json' '{"clixon-example:output":{"x":"0","y":"42"}}'

new "restconf example rpc xml/json"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' -H 'Accept: application/yang-data+json' -d '<input xmlns="urn:example:clixon"><x>0</x></input>' $RCPROTO://localhost/restconf/operations/clixon-example:example)"  0 'Content-Type: application/yang-data+json' '{"clixon-example:output":{"x":"0","y":"42"}}'

new "restconf example rpc json/xml"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' -H 'Accept: application/yang-data+xml' -d '{"clixon-example:input":{"x":"0"}}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'Content-Type: application/yang-data+xml' '<output xmlns="urn:example:clixon"><x>0</x><y>42</y></output>'

new "restconf example rpc xml/xml"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' -H 'Accept: application/yang-data+xml' -d '<input xmlns="urn:example:clixon"><x>0</x></input>' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'Content-Type: application/yang-data+xml' '<output xmlns="urn:example:clixon"><x>0</x><y>42</y></output>'

new "restconf example rpc xml in w json encoding (expect fail)"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' -H 'Accept: application/yang-data+xml' -d '<input xmlns="urn:example:clixon"><x>0</x></input>' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'HTTP/1.1 400 Bad Request' "<errors xmlns=\"urn:ietf:params:xml:ns:yang:ietf-restconf\"><error><error-type>rpc</error-type><error-tag>malformed-message</error-tag><error-severity>error</error-severity><error-message>json_parse: line 1: syntax error at or before: '&lt;'</error-message></error></errors>"

new "restconf example rpc json in xml encoding (expect fail)"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' -H 'Accept: application/yang-data+xml' -d '{"clixon-example:input":{"x":"0"}}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'HTTP/1.1 400 Bad Reques' '<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-type>rpc</error-type><error-tag>malformed-message</error-tag><error-severity>error</error-severity><error-message>xml_parse: line 0: syntax error: at or before: "</error-message></error></errors>'

new "netconf example rpc"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><example xmlns="urn:example:clixon"><x>0</x></example></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><x xmlns="urn:example:clixon">0</x><y xmlns="urn:example:clixon">42</y></rpc-reply>]]>]]>$'

# 2. Then error cases
#
new "restconf empty rpc with null input"
ret=$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":null}' $RCPROTO://localhost/restconf/operations/clixon-example:empty)
expect="204 No Content"
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf empty rpc with input x"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":0}}' $RCPROTO://localhost/restconf/operations/clixon-example:empty)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"x"},"error-severity":"error","error-message":"Unrecognized parameter: x in rpc: empty"}}}'

# cornercase: optional has yang input/output sections but test without body
new "restconf optional rpc with null input and output"
ret=$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":null}' $RCPROTO://localhost/restconf/operations/clixon-example:optional)
expect="204 No Content"
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf omit mandatory"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":null}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"missing-element","error-info":{"bad-element":"x"},"error-severity":"error","error-message":"Mandatory variable"}}}'

new "restconf add extra w/o yang: should fail"
if ! $YANG_UNKNOWN_ANYDATA ; then
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":"0","extra":"0"}}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"bad-element","error-info":{"bad-element":"extra"},"error-severity":"error","error-message":"Failed to find YANG spec of XML node: extra with parent: example in namespace: urn:example:clixon"}}}'
fi

new "restconf wrong method"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":"0"}}' $RCPROTO://localhost/restconf/operations/clixon-example:wrong)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"missing-element","error-info":{"bad-element":"wrong"},"error-severity":"error","error-message":"RPC not defined"}}}'

new "restconf example missing input"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":null}' $RCPROTO://localhost/restconf/operations/ietf-netconf:edit-config)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"missing-element","error-info":{"bad-element":"target"},"error-severity":"error","error-message":"Mandatory variable"}}}'

new "netconf kill-session missing session-id mandatory"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><kill-session/></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>missing-element</error-tag><error-info><bad-element>session-id</bad-element></error-info><error-severity>error</error-severity><error-message>Mandatory variable</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf edit-config ok"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><target><candidate/></target><config/></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

if ! $YANG_UNKNOWN_ANYDATA ; then
new "netconf edit-config extra arg: should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><target><candidate/></target><extra/><config/></edit-config></rpc>]]>]]>' "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>extra</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: extra with parent: edit-config in namespace: urn:ietf:params:xml:ns:netconf:base:1.0</error-message></rpc-error></rpc-reply>]]>]]>$"
fi

new "netconf edit-config empty target: should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><target/><config/></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>missing-choice</error-app-tag><error-info><missing-choice>config-target</missing-choice></error-info><error-severity>error</error-severity></rpc-error></rpc-reply>]]>]]>$'

new "netconf edit-config missing target: should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><config/></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>missing-element</error-tag><error-info><bad-element>target</bad-element></error-info><error-severity>error</error-severity><error-message>Mandatory variable</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf edit-config missing config: should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><target><candidate/></target></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>missing-choice</error-app-tag><error-info><missing-choice>edit-content</missing-choice></error-info><error-severity>error</error-severity></rpc-error></rpc-reply>]]>]]>$'

# Negative errors (namespace/module missing)
new "netconf wrong rpc namespace: should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:example:xxx"><get/></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>get</bad-element></error-info><error-severity>error</error-severity></rpc-error></rpc-reply>]]>]]>$'

new "restconf wrong rpc: should fail"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" u $RCPROTO://localhost/restconf/operations/clixon-foo:get)" 0 'HTTP/1.1 412 Precondition Failed' '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"yang module not found"}}}'

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
