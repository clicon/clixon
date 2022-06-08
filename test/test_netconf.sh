#!/usr/bin/env bash
# Basic Netconf functionality
# Mainly default/null prefix, but also xx: prefix
# XXX: could add tests for dual prefixes xx and xy with doppelganger names, ie xy:filter that is
# syntactic correct but wrong

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
tmp=$dir/tmp.x

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_NETCONF_MESSAGE_ID_OPTIONAL>false</CLICON_NETCONF_MESSAGE_ID_OPTIONAL>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
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

# Framing. with -q to inhibit rcv hello
new "Empty frame"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 ']]>]]>' "" '<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><rpc-error><error-type>rpc</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Empty XML</error-message></rpc-error></rpc-reply>]]>]]>' ""

if [ $valgrindtest -eq 0 ]; then # Some leakage in lex / error handling difficult to catch
new "Frame invalid non-xml"
expecteof "$clixon_netconf -qf $cfg" 0 "This is not XML]]>]]>" '<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><rpc-error><error-type>rpc</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>xml_parse: line 0: syntax error: at or before: This</error-message></rpc-error></rpc-reply>]]>]]>' 2> /dev/null
fi

new "Frame with two messages"
expecteof "$clixon_netconf -qf $cfg" 0 "<hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello><rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><rpc-error><error-type>rpc</error-type><error-tag>malformed-message</error-tag><error-severity>error</error-severity><error-message>More than one message in netconf rpc frame</error-message></rpc-error></rpc-reply>]]>]]>'

new "Frame with unknown message"
expecteof "$clixon_netconf -qf $cfg" 0 "<xxx $DEFAULTNS></xxx>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>xxx</bad-element></error-info><error-severity>error</error-severity><error-message>Unrecognized netconf operation</error-message></rpc-error></rpc-reply>]]>]]>$"

new "Frame without message-id attribute"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "" "<rpc $DEFAULTONLY><get-config><source><candidate/></source></get-config></rpc>" "^<rpc-reply $DEFAULTONLY><rpc-error><error-type>rpc</error-type><error-tag>missing-attribute</error-tag><error-info><bad-attribute>message-id</bad-attribute></error-info><error-severity>error</error-severity><error-message>Incoming rpc</error-message></rpc-error></rpc-reply>$"

#<capability>urn:ietf:params:netconf:base:1.1</capability>
new "netconf rcv hello, disable RFC7895/ietf-yang-library"
expecteof_netconf "$clixon_netconf -f $cfg -o CLICON_YANG_LIBRARY=0" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "netconf get-config nc prefix"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<nc:rpc xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:message-id=\"42\"><nc:get-config><nc:source><nc:candidate/></nc:source></nc:get-config></nc:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:message-id=\"42\"><data/></rpc-reply>"

new "netconf get-config xx prefix"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:get-config><xx:source><xx:candidate/></xx:source></xx:get-config></xx:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><data/></rpc-reply>"

new "netconf get-config double quotes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "netconf get-config single quotes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "Add subtree eth/0/0 using none which should not change anything"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>none</default-operation><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Trying prefixes
new "Add subtree eth/0/0 using nc prefix"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<nc:rpc xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:message-id=\"42\"><nc:edit-config><nc:default-operation>none</nc:default-operation><nc:target><nc:candidate/></nc:target><nc:config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name></interface></interfaces></nc:config></nc:edit-config></nc:rpc>" "" "<rpc-reply $DEFAULTONLY xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:message-id=\"42\"><ok/></rpc-reply>"

new "Add subtree eth/0/0 using xx prefix"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:edit-config><xx:default-operation>none</xx:default-operation><xx:target><xx:candidate/></xx:target><xx:config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name></interface></interfaces></xx:config></xx:edit-config></xx:rpc>" "" "<rpc-reply $DEFAULTONLY xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><ok/></rpc-reply>"

new "Check nothing added"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "Add subtree eth/0/0 using none and create which should add eth/0/0"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"create\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Too many quotes, (single inside double inside single) need to fool bash
rpc=$(chunked_framing "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/if:interfaces/if:interface[if:name='eth/0/0']\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"/></get-config></rpc>")
cat <<EOF > $tmp # new
$DEFAULTHELLO$rpc
EOF

new "Check eth/0/0 added using xpath"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$rpc" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>"

new "Re-create same eth/0/0 which should generate error"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"create\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error>" ""

new "Delete eth/0/0 using none config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check deleted eth/0/0 (non-presence container)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "Re-Delete eth/0/0 using none should generate error"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error>" ""

new "Add interface without key"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"create\"><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>missing-element</error-tag><error-info><bad-element>name</bad-element></error-info><error-severity>error</error-severity><error-message>Mandatory key</error-message></rpc-error></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes using xx prefix"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:discard-changes/></xx:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><ok/></rpc-reply>"

new "netconf edit config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name></interface><interface xmlns:ip=\"urn:ietf:params:xml:ns:yang:ietf-ip\"><name>eth1</name><enabled>true</enabled><ip:ipv4><ip:address><ip:ip>9.2.3.4</ip:ip><ip:prefix-length>24</ip:prefix-length></ip:address></ip:ipv4></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

rpc="<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/if:interfaces/if:interface[if:name='eth1']/if:enabled\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"/></get-config></rpc>"

new "netconf get config xpath"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$rpc" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth1</name><enabled>true</enabled></interface></interfaces></data></rpc-reply>"

rpc="<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/if:interfaces/if:interface[if:name='eth1']/if:enabled/../..\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"/></get-config></rpc>"

new "netconf get config xpath parent"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$rpc" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><enabled>true</enabled></interface><interface><name>eth1</name><enabled>true</enabled><ipv4 xmlns=\"urn:ietf:params:xml:ns:yang:ietf-ip\"><enabled>true</enabled><forwarding>false</forwarding><address><ip>9.2.3.4</ip><prefix-length>24</prefix-length></address></ipv4></interface></interfaces></data></rpc-reply>"

new "netconf validate missing type"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error>" ""

new "netconf validate using xx prefix"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:validate><xx:source><xx:candidate/></xx:source></xx:validate></xx:rpc>" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><rpc-error>" ""

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get empty config2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "netconf edit extra xml"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><extra/></interfaces></config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error>" ""

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf edit config eth1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth1</name><type>ex:eth</type></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit using prefix xx"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:commit/></xx:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><ok/></rpc-reply>"

new "netconf edit config merge eth2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth2</name><type>ex:eth</type></interface></interfaces></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Note, the type here is non-existant identityref, fails on validation
new "netconf edit ampersand encoding(<&): name:'eth&' type:'t<>'"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth&amp;</name><type>t&lt;&gt;</type></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get replaced config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth&amp;</name><type>t&lt;&gt;</type><enabled>true</enabled></interface><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>eth2</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>"

new "cli show configuration eth& - encoding tests"
expectpart "$($clixon_cli -1 -f $cfg show conf cli)" 0 "interfaces interface eth& type t<>
interfaces interface eth& enabled true"

new "netconf edit CDATA"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>ex:eth</type><description><![CDATA[myeth&]]></description></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

#new "netconf get CDATA"
#expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/interfaces/interface[name='eth/0/0']/description\" /></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth/0/0</name><description><![CDATA[myeth&]]></description><enabled>true</enabled></interface></interfaces></data></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf edit state operation should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>e0</name><oper-status>up</oper-status></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>oper-status</bad-element></error-info><error-severity>error</error-severity><error-message>module ietf-interfaces: state data node unexpected</error-message></rpc-error></rpc-reply>"

new "netconf get state operation"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/if:interfaces\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" /></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled><oper-status>up</oper-status><ex:my-status xmlns:ex=\"urn:example:clixon\"><ex:int>42</ex:int><ex:str>foo</ex:str></ex:my-status></interface></interfaces></data></rpc-reply>"

new "netconf get state operation use prefix xx"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:get><xx:filter xx:type=\"xpath\" xx:select=\"/if:interfaces\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" /></xx:get></xx:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled><oper-status>up</oper-status><ex:my-status xmlns:ex=\"urn:example:clixon\"><ex:int>42</ex:int><ex:str>foo</ex:str></ex:my-status></interface></interfaces></data></rpc-reply>"

new "netconf lock" 
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf unlock" 
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><unlock><target><candidate/></target></unlock></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>lock-denied</error-tag><error-info><session-id>0</session-id></error-info><error-severity>error</error-severity><error-message>Unlock failed, lock is not currently active</error-message></rpc-error></rpc-reply>"

new "netconf lock using prefix xx" 
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:lock><xx:target><xx:candidate/></xx:target></xx:lock></xx:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><ok/></rpc-reply>"

new "netconf unlock using prefix xx" 
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:unlock><xx:target><xx:candidate/></xx:target></xx:unlock></xx:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><rpc-error><error-type>protocol</error-type><error-tag>lock-denied</error-tag><error-info><session-id>0</session-id></error-info><error-severity>error</error-severity><error-message>Unlock failed, lock is not currently active</error-message></rpc-error></rpc-reply>"

# send multiple frames
rpc=$(chunked_framing "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>")
rpc="${rpc}
$(chunked_framing "<rpc $DEFAULTNS><unlock><target><candidate/></target></unlock></rpc>")"
reply=$(chunked_framing "<rpc-reply $DEFAULTNS><ok/></rpc-reply")
reply=${reply}$(chunked_framing "<rpc-reply $DEFAULTNS><ok/></rpc-reply")
new "netconf lock/unlock"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO$rpc" "$reply"

rpc=$(chunked_framing "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>")
rpc="${rpc}
$(chunked_framing "<rpc $DEFAULTNS><unlock><target><candidate/></target></unlock></rpc>")"
new "netconf lock/unlock/lock"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO$rpc" "$reply"

rpc=$(chunked_framing "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>")
rpc="${rpc}
$(chunked_framing "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>")"
new "netconf lock/lock"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO$rpc" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>lock-denied</error-tag><error-info><sessi"

rpc=$(chunked_framing "<rpc $DEFAULTNS><unlock><target><candidate/></target></unlock></rpc>")
rpc="${rpc}
$(chunked_framing "<rpc $DEFAULTNS><unlock><target><candidate/></target></unlock></rpc>")"
new "netconf unlock/unlock"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO$rpc" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>lock-denied</error-tag><error-info><session-id>0</session-id></error-info><error-severity>error</error-severity><error-message>Unlock failed, lock is not currently active</error-message></rpc-error></rpc-reply>"

new "close-session"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><close-session/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "close-session using prefix xx"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:close-session/></xx:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><ok/></rpc-reply>"

# XXX NOTE that this does not actually kill a running session - and may even kill some random process,...
new "kill-session"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><kill-session><session-id>44</session-id></kill-session></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "kill-session using prefix xx"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:kill-session><xx:session-id>44</xx:session-id></xx:kill-session></xx:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><ok/></rpc-reply>"

# modify candidate, then lock, should fail.
new "netconf edit config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>a</name></parameter></table></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf lock: should fail" 
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>lock-denied</error-tag><error-info><session-id>0</session-id></error-info><error-severity>error</error-severity><error-message>Operation failed, candidate has already been modified and the changes have not been committed or rolled back (RFC 6241 7.5)</error-message></rpc-error></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf lock"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "copy startup to candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><copy-config><target><startup/></target><source><candidate/></source></copy-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "copy startup to candidate using prefix xx"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:copy-config><xx:target><xx:startup/></xx:target><xx:source><xx:candidate/></xx:source></xx:copy-config></xx:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><ok/></rpc-reply>"

new "netconf get startup"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><startup/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>"

new "netconf delete startup"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><delete-config><target><startup/></target></delete-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf delete startup using prefix xx"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><xx:delete-config><xx:target><xx:startup/></xx:target></xx:delete-config></xx:rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><ok/></rpc-reply>"

new "netconf check empty startup"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><startup/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "netconf example rpc"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><example xmlns=\"urn:example:clixon\"><x>42</x></example></rpc>" "" "<rpc-reply $DEFAULTNS><x xmlns=\"urn:example:clixon\">42</x><y xmlns=\"urn:example:clixon\">42</y></rpc-reply>"

new "netconf example rpc using prefix xx"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<xx:rpc xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\" xx:message-id=\"42\"><example xmlns=\"urn:example:clixon\"><x>42</x></example></xx:rpc>" "" "<rpc-reply $DEFAULTNS xmlns:xx=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><x xmlns=\"urn:example:clixon\">42</x><y xmlns=\"urn:example:clixon\">42</y></rpc-reply>"

new "netconf empty rpc"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><empty xmlns=\"urn:example:clixon\"/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf client-side rpc"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><client-rpc xmlns=\"urn:example:clixon\"><x>val42</x></client-rpc></rpc>" "" "<rpc-reply $DEFAULTNS><x xmlns=\"urn:example:clixon\">val42</x></rpc-reply>"

new "netconf extra leaf in leaf should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>e0<name>e1</name></name></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>name</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: name with parent: name in namespace: urn:ietf:params:xml:ns:yang:ietf-interfaces</error-message></rpc-error></rpc-reply>"

# Negative tests
new "netconf xpath syntax error (api-path not xpath) should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/if:interfaces/interface=eth2f0,foo/fii\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>xpath parser on line 1: syntax error at or before: ','</error-message></rpc-error></rpc-reply>"

new "netconf wrong xpath should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/if:interfaces/interface=eth2f0/fii\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

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
