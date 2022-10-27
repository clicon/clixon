#!/usr/bin/env bash
# Netconf Hello functionality
# See RFC6241 Sec 8.1
# For prolog, ie <?xml ..> see test_xml.sh
# Note clixon sends rpc-error back on primitive errors prior to knowing it is an rpc.
# This means that some errors for hello messages get an rpc-error back which is somewhat
# fringe to the standard.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang
tmp=$dir/tmp.x

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE> 
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_NETCONF_BASE_CAPABILITY>1</CLICON_NETCONF_BASE_CAPABILITY>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
}
EOF

new "test params: -f $cfg -- -s"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend  -s init -f $cfg -- -s"
    start_backend -s init -f $cfg -- -s
fi

new "wait backend"
wait_backend

# Hello
new "Netconf snd hello with xmldecl"
expecteof "$clixon_netconf -qef $cfg" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability></capabilities></hello>]]>]]>" '^$'

# Hello, lowercase encoding
new "Netconf snd hello with xmldecl (cap 1.0)"
expecteof "$clixon_netconf -qef $cfg" 0 "<?xml version=\"1.0\" encoding=\"utf-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>" '^$'

new "Netconf snd hello without xmldecl"
expecteof "$clixon_netconf -qef $cfg" 0 "<hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>" '^$'

new "Netconf capability: 1.0 + 1.1 -> 1.0"
expecteof "$clixon_netconf -ef $cfg" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability></capabilities></hello>]]>]]>" '<capability>urn:ietf:params:netconf:base:1.0</capability>'

new "Netconf capability: 1.1 + 1.1 -> 1.1"
expecteof "$clixon_netconf -ef $cfg" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>" '<capability>urn:ietf:params:netconf:base:1.1</capability>'

new "Netconf capability: 1.0 + 1.0 -> 1.0"
expecteof "$clixon_netconf -ef $cfg -o CLICON_NETCONF_BASE_CAPABILITY=0" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability></capabilities></hello>]]>]]>" '<capability>urn:ietf:params:netconf:base:1.0</capability>'

new "Netconf capability: 1.1 + 1.0 -> Error"
expecteof "$clixon_netconf -ef $cfg -o CLICON_NETCONF_BASE_CAPABILITY=0" 255 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>" '<capability>urn:ietf:params:netconf:base:1.0</capability>'

new "Netconf snd hello with wrong base capability"
expecteof "$clixon_netconf -qef $cfg -l e" 255 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.2</capability></capabilities></hello>]]>]]>" '^$' 'Server received hello without matching netconf base capability'

new "Netconf hello with MUST NOT have a session-id, terminate"
expecteof "$clixon_netconf -qef $cfg" 255 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><session-id>42</session-id><capabilities><capability>urn:ietf:params:netconf:base:1.2</capability></capabilities></hello>]]>]]>" '^$'

# When comparing protocol version capability URIs, only the base part is used, in the event any
# parameters are encoded at the end of the URI string. 
new "Netconf snd hello with base capability with extra arguments"
expecteof "$clixon_netconf -qef $cfg" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.1?arg=val</capability></capabilities></hello>]]>]]>" '^$'

new "Netconf hello with wrong namespace -> terminate"
expecteof "$clixon_netconf -qef $cfg" 255 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello xmlns='urn:xxx:wrong'><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>" '^$' 2> /dev/null

# This is hello - shouldnt really get rpc back?
new "Netconf snd hello with wrong prefix"
expecteof "$clixon_netconf -qef $cfg" 255 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><xx:hello xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><nc:capabilities><nc:capability>urn:ietf:params:netconf:base:1.1</nc:capability></nc:capabilities></xx:hello>]]>]]>" '^$' 2> /dev/null

new "Netconf snd hello with prefix"
expecteof "$clixon_netconf -qef $cfg" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><nc:hello xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><nc:capabilities><nc:capability>urn:ietf:params:netconf:base:1.1</nc:capability></nc:capabilities></nc:hello>]]>]]>" '^$'

new "netconf snd + rcv hello"
expecteof "$clixon_netconf -f $cfg" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTONLY><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>" "^<hello $DEFAULTONLY><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability><capability>urn:ietf:params:netconf:base:1.0</capability>
<capability>urn:ietf:params:netconf:capability:yang-library:1.0?revision=2019-01-04&amp;module-set-id=42</capability>
<capability>urn:ietf:params:netconf:capability:candidate:1.0</capability>
<capability>urn:ietf:params:netconf:capability:validate:1.1</capability>
<capability>urn:ietf:params:netconf:capability:xpath:1.0</capability>
<capability>urn:ietf:params:netconf:capability:notification:1.0</capability>
<capability>urn:ietf:params:netconf:capability:startup:1.0</capability>
<capability>urn:ietf:params:netconf:capability:with-defaults:1.0?basic-mode=explicit&amp;also-supported=report-all,trim,report-all-tagged</capability>
</capabilities><session-id>[0-9]*</session-id></hello>]]>]]>$" '^$'

# Actually non-standard to reply on wrong hello with rpc-error, but may be useful
new "Netconf snd hello with extra element"
expecteof "$clixon_netconf -qef $cfg" 0 "<hello $DEFAULTONLY><capabilities><extra-element/><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>" '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><rpc-error><error-type>protocol</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>extra-element</bad-element></error-info><error-severity>error</error-severity><error-message>Unrecognized hello/capabilities element</error-message></rpc-error></rpc-reply>]]>]]>$' '^$'

new "Netconf send rpc without hello error"
expecteof "$clixon_netconf -qef $cfg" 255 "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>rpc</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Client must send an hello element before any RPC</error-message></rpc-error></rpc-reply>]]>]]>" '^$'

# same as -H
new "Netconf send rpc without hello w CLICON_NETCONF_HELLO_OPTIONAL"
expecteof_netconf "$clixon_netconf -qef $cfg -o CLICON_NETCONF_HELLO_OPTIONAL=true" 0 "" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

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
