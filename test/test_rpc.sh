#!/bin/bash
# RPC tests
# Validate parameters in restconf and netconf, check namespaces, etc
# See rfc8040 3.6
APPNAME=example

# include err() and new() functions and creates $dir
. ./lib.sh
cfg=$dir/conf.xml

# Use yang in example
cat <<EOF > $cfg
<config xmlns="urn:example:clixon">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/$APPNAME/yang</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>$APPNAME</CLICON_YANG_MODULE_MAIN>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    sudo $clixon_backend -s init -f $cfg -D $DBG
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
sudo su -c "$clixon_restconf -f $cfg" -s /bin/sh www-data &

sleep $RCWAIT

new "rpc tests"

# 1.First some positive tests vary media types
#
new2 "restconf example rpc json/json default - no headers"
expecteq "$(curl -s -X POST -d '{"input":{"x":"0"}}' http://localhost/restconf/operations/example:example)" '{"output": {"x": "0","y": "42"}}
'

new2 "restconf example rpc json/json change y default"
expecteq "$(curl -s -X POST -d '{"input":{"x":"0","y":"99"}}' http://localhost/restconf/operations/example:example)" '{"output": {"x": "0","y": "99"}}
'

new2 "restconf example rpc json/json"
# XXX example:input example:output
expecteq "$(curl -s -X POST -H 'Content-Type: application/yang-data+json' -H 'Content-Type: application/yang-data+json' -d '{"input":{"x":"0"}}' http://localhost/restconf/operations/example:example)" '{"output": {"x": "0","y": "42"}}
'

new2 "restconf example rpc xml/json"
expecteq "$(curl -s -X POST -H 'Content-Type: application/yang-data+xml' -H 'Content-Type: application/yang-data+json' -d '<input xmlns="urn:example:clixon"><x>0</x></input>' http://localhost/restconf/operations/example:example)"  '{"output": {"x": "0","y": "42"}}
'

new2 "restconf example rpc json/xml"
# <output xmlns="rn:example:clixon"
expecteq "$(curl -s -X POST -H 'Content-Type: application/yang-data+json' -H 'Accept: application/yang-data+xml' -d '{"input":{"x":"0"}}' http://localhost/restconf/operations/example:example)" '<output><x>0</x><y>42</y></output>
'

new2 "restconf example rpc xml/xml"
# <output xmlns="rn:example:clixon"
expecteq "$(curl -s -X POST -H 'Content-Type: application/yang-data+xml' -H 'Accept: application/yang-data+xml'  -d '<input xmlns="urn:example:clixon"><x>0</x></input>' http://localhost/restconf/operations/example:example)" '<output><x>0</x><y>42</y></output>
'

new "netconf example rpc"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><example><x>0</x></example></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><x>0</x><y>42</y></rpc-reply>]]>]]>$'

# 2. Then error cases
#
new2 "restconf omit mandatory"
expecteq "$(curl -s -X POST -d '{"input":null}' http://localhost/restconf/operations/example:example)" '{"ietf-restconf:errors" : {"error": {"error-type": "application","error-tag": "missing-element","error-info": {"bad-element": "x"},"error-severity": "error","error-message": "Mandatory variable"}}}'

new2 "restconf add extra"
expecteq "$(curl -s -X POST -d '{"input":{"x":"0","extra":"0"}}' http://localhost/restconf/operations/example:example)" '{"ietf-restconf:errors" : {"error": {"error-type": "application","error-tag": "unknown-element","error-info": {"bad-element": "extra"},"error-severity": "error"}}}'

new2 "restconf wrong method"
expecteq "$(curl -s -X POST -d '{"input":{"x":"0"}}' http://localhost/restconf/operations/example:wrong)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "operation-failed","error-severity": "error","error-message": "yang node not found"}}}'

new2 "restconf edit-config missing mandatory"
expecteq "$(curl -s -X POST -d '{"input":null}' http://localhost/restconf/operations/ietf-netconf:edit-config)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "operation-failed","error-severity": "error","error-message": "yang module not found"}}}'

new "netconf kill-session missing session-id mandatory"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><kill-session/></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>missing-element</error-tag><error-info><bad-element>session-id</bad-element></error-info><error-severity>error</error-severity><error-message>Mandatory variable</error-message></rpc-error></rpc-reply>$'

# edit-config?

new "Kill restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
