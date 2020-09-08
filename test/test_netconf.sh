#!/usr/bin/env bash
# Basic Netconf functionality

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
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
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

    new "waiting"
    wait_backend
fi

new "netconf hello"
expecteof "$clixon_netconf -f $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:capability:yang-library:1.0?revision=2016-06-21&amp;module-set-id=42</capability><capability>urn:ietf:params:netconf:capability:candidate:1.0</capability><capability>urn:ietf:params:netconf:capability:validate:1.1</capability><capability>urn:ietf:params:netconf:capability:startup:1.0</capability><capability>urn:ietf:params:netconf:capability:xpath:1.0</capability><capability>urn:ietf:params:netconf:capability:notification:1.0</capability></capabilities><session-id>[0-9]*</session-id></hello>]]>]]><rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

new "netconf hello, disable RFC7895/ietf-yang-library"
expecteof "$clixon_netconf -f $cfg -o CLICON_MODULE_LIBRARY_RFC7895=0" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:capability:candidate:1.0</capability><capability>urn:ietf:params:netconf:capability:validate:1.1</capability><capability>urn:ietf:params:netconf:capability:startup:1.0</capability><capability>urn:ietf:params:netconf:capability:xpath:1.0</capability><capability>urn:ietf:params:netconf:capability:notification:1.0</capability></capabilities><session-id>[0-9]*</session-id></hello>]]>]]><rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

new "netconf get-config double quotes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

new "netconf get-config single quotes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id='101'><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

new "Add subtree eth/0/0 using none which should not change anything"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><default-operation>none</default-operation><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Check nothing added"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

new "Add subtree eth/0/0 using none and create which should add eth/0/0"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"create\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# Too many quotes, (single inside double inside single) need to fool bash
cat <<EOF > $tmp # new
<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type="xpath" select="/if:interfaces/if:interface[if:name='eth/0/0']" xmlns:if="urn:ietf:params:xml:ns:yang:ietf-interfaces"/></get-config></rpc>]]>]]>
EOF

new "Check eth/0/0 added using xpath"
expecteof "$clixon_netconf -qf $cfg" 0 "$(cat $tmp)" "^<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

new "Re-create same eth/0/0 which should generate error"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"create\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error>"

new "Delete eth/0/0 using none config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Check deleted eth/0/0 (non-presence container)"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

new "Re-Delete eth/0/0 using none should generate error"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error>"

new "Add interface without key"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"create\"><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>missing-element</error-tag><error-info><bad-element>name</bad-element></error-info><error-severity>error</error-severity><error-message>Mandatory key</error-message></rpc-error></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf edit config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name></interface><interface xmlns:ip=\"urn:ietf:params:xml:ns:yang:ietf-ip\"><name>eth1</name><enabled>true</enabled><ip:ipv4><ip:address><ip:ip>9.2.3.4</ip:ip><ip:prefix-length>24</ip:prefix-length></ip:address></ip:ipv4></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# Too many quotes
cat <<EOF > $tmp # new
<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type="xpath" select="/if:interfaces/if:interface[if:name='eth1']/if:enabled" xmlns:if="urn:ietf:params:xml:ns:yang:ietf-interfaces"/></get-config></rpc>]]>]]>
EOF

new "netconf get config xpath"
expecteof "$clixon_netconf -qf $cfg" 0 "$(cat $tmp)" "^<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth1</name><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

# Too many quotes
cat <<EOF > $tmp # new
<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type="xpath" select="/if:interfaces/if:interface[if:name='eth1']/if:enabled/../.." xmlns:if="urn:ietf:params:xml:ns:yang:ietf-interfaces"/></get-config></rpc>]]>]]>
EOF

new "netconf get config xpath parent"
expecteof "$clixon_netconf -qf $cfg" 0 "$(cat $tmp)" "^<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><enabled>true</enabled></interface><interface><name>eth1</name><enabled>true</enabled><ip:ipv4 xmlns:ip=\"urn:ietf:params:xml:ns:yang:ietf-ip\"><ip:enabled>true</ip:enabled><ip:forwarding>false</ip:forwarding><ip:address><ip:ip>9.2.3.4</ip:ip><ip:prefix-length>24</ip:prefix-length></ip:address></ip:ipv4></interface></interfaces></data></rpc-reply>]]>]]>$"

new "netconf validate missing type"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error>"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf get empty config2"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data/></rpc-reply>]]>]]>$"

new "netconf edit extra xml"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><extra/></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error>"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf edit config eth1"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth1</name><type>ex:eth</type></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf edit config merge eth2"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth2</name><type>ex:eth</type></interface></interfaces></config><default-operation>merge</default-operation></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# Note, the type here is non-existant identityref, fails on validation
new "netconf edit ampersand encoding(<&): name:'eth&' type:'t<>'"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth&amp;</name><type>t&lt;&gt;</type></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf get replaced config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth&amp;</name><type>t&lt;&gt;</type><enabled>true</enabled></interface><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>eth2</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

new "cli show configuration eth& - encoding tests"
expectfn "$clixon_cli -1 -f $cfg show conf cli" 0 "interfaces interface eth& type t<>
interfaces interface eth& enabled true"

new "netconf edit CDATA"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>ex:eth</type><description><![CDATA[myeth&]]></description></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

#new "netconf get CDATA"
#expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/interfaces/interface[name='eth/0/0']/description\" /></get-config></rpc>]]>]]>" "<rpc-reply $DEFAULTNS><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth/0/0</name><description><![CDATA[myeth&]]></description><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf edit state operation should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>e0</name><oper-status>up</oper-status></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>State data not allowed</error-message></rpc-error></rpc-reply>]]>]]>"

new "netconf get state operation"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/if:interfaces\" xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" /></get></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled><oper-status>up</oper-status><ex:my-status xmlns:ex=\"urn:example:clixon\"><ex:int>42</ex:int><ex:str>foo</ex:str></ex:my-status></interface></interfaces></data></rpc-reply>]]>]]>$"

new "netconf lock" 
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf unlock" 
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><unlock><target><candidate/></target></unlock></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>lock-denied</error-tag><error-info><session-id>0</session-id></error-info><error-severity>error</error-severity><error-message>Unlock failed, lock is not currently active</error-message></rpc-error></rpc-reply>]]>]]>$"

new "netconf lock/unlock"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>]]>]]><rpc $DEFAULTNS><unlock><target><candidate/></target></unlock></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]><rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf lock/lock"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>]]>]]><rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]><rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>lock-denied</error-tag><error-info><session-id>" 

new "netconf unlock/unlock"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><unlock><target><candidate/></target></unlock></rpc>]]>]]><rpc $DEFAULTNS><unlock><target><candidate/></target></unlock></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>lock-denied</error-tag><error-info><session-id>0</session-id></error-info><error-severity>error</error-severity><error-message>Unlock failed, lock is not currently active</error-message></rpc-error></rpc-reply>]]>]]><rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>lock-denied</error-tag><error-info><session-id>0</session-id></error-info><error-severity>error</error-severity><error-message>Unlock failed, lock is not currently active</error-message></rpc-error></rpc-reply>]]>]]>$"

new "close-session"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><close-session/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# XXX NOTE that this does not actually kill a running session - and may even kill some random process,...
new "kill-session"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><kill-session><session-id>44</session-id></kill-session></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# modify candidate, then lock, should fail.
new "netconf edit config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>a</name></parameter></table></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf lock: should fail" 
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>lock-denied</error-tag><error-info><session-id>0</session-id></error-info><error-severity>error</error-severity><error-message>Operation failed, candidate has already been modified and the changes have not been committed or rolled back (RFC 6241 7.5)</error-message></rpc-error></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf lock"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "copy startup to candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><copy-config><target><startup/></target><source><candidate/></source></copy-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf get startup"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get-config><source><startup/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

new "netconf delete startup"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><delete-config><target><startup/></target></delete-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf check empty startup"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get-config><source><startup/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data/></rpc-reply>]]>]]>$"

new "netconf example rpc"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><example xmlns=\"urn:example:clixon\"><x>42</x></example></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><x xmlns=\"urn:example:clixon\">42</x><y xmlns=\"urn:example:clixon\">42</y></rpc-reply>]]>]]>$"

new "netconf empty rpc"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><empty xmlns=\"urn:example:clixon\"/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf client-side rpc"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><client-rpc xmlns=\"urn:example:clixon\"><x>val42</x></client-rpc></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><x xmlns=\"urn:example:clixon\">val42</x></rpc-reply>]]>]]>$"

new "netconf extra leaf in leaf should fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>e0<name>e1</name></name></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>name</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: name with parent: name in namespace: urn:ietf:params:xml:ns:yang:ietf-interfaces</error-message></rpc-error></rpc-reply>]]>]]>$"

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
