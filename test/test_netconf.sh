#!/bin/bash
# Test2: backend and netconf basic functionality
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
tmp=$dir/tmp.x

# Use yang in example

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
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
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

new "test params: -f $cfg"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s init -f $cfg"
    # start new backend
    sudo $clixon_backend -s init -f $cfg -D $DBG
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "netconf hello"
expecteof "$clixon_netconf -f $cfg" 0 '<rpc message-id="101"><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:capability:yang-library:1.0?revision=2016-06-21&amp;module-set-id=42</capability><capability>urn:ietf:params:netconf:capability:candidate:1:0</capability><capability>urn:ietf:params:netconf:capability:validate:1.1</capability><capability>urn:ietf:params:netconf:capability:startup:1.0</capability><capability>urn:ietf:params:netconf:capability:xpath:1.0</capability><capability>urn:ietf:params:netconf:capability:notification:1.0</capability></capabilities><session-id>[0-9]*</session-id></hello>]]>]]><rpc-reply message-id="101"><data/></rpc-reply>]]>]]>$'

new "netconf get-config double quotes"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<rpc-reply message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><data/></rpc-reply>]]>]]>$'

new "netconf get-config single quotes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc message-id='101' xmlns='urn:ietf:params:xml:ns:netconf:base:1.0'><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><data/></rpc-reply>]]>]]>$'

new "Add subtree eth/0/0 using none which should not change anything"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><default-operation>none</default-operation><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth/0/0</name></interface></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Check nothing added"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc message-id="101"><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<rpc-reply message-id="101"><data/></rpc-reply>]]>]]>$'

new "Add subtree eth/0/0 using none and create which should add eth/0/0"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface operation="create"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Too many quotes, (single inside double inside single) need to fool bash
cat <<EOF > $tmp # new
<rpc><get-config><source><candidate/></source><filter type="xpath" select="/interfaces/interface[name='eth/0/0']"/></get-config></rpc>]]>]]>
EOF

new "Check eth/0/0 added using xpath"
expecteof "$clixon_netconf -qf $cfg" 0 "$(cat $tmp)" '^<rpc-reply><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth/0/0</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$'

new "Re-create same eth/0/0 which should generate error"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface operation="create"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error>'

new "Delete eth/0/0 using none config"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface operation="delete"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>'  '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Check deleted eth/0/0 (non-presence container)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc message-id="101"><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<rpc-reply message-id="101"><data/></rpc-reply>]]>]]>$'

new "Re-Delete eth/0/0 using none should generate error"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface operation="delete"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>'  '^<rpc-reply><rpc-error>'

new "netconf edit config"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth/0/0</name></interface><interface><name>eth1</name><enabled>true</enabled><ipv4><address><ip>9.2.3.4</ip><prefix-length>24</prefix-length></address></ipv4></interface></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Too many quotes
cat <<EOF > $tmp # new
<rpc><get-config><source><candidate/></source><filter type="xpath" select="/interfaces/interface[name='eth1']/enabled"/></get-config></rpc>]]>]]>
EOF

new "netconf get config xpath"
expecteof "$clixon_netconf -qf $cfg" 0 "$(cat $tmp)" '^<rpc-reply><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth1</name><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$'

# Too many quotes
cat <<EOF > $tmp # new
<rpc><get-config><source><candidate/></source><filter type="xpath" select="/interfaces/interface[name='eth1']/enabled/../.."/></get-config></rpc>]]>]]>
EOF

new "netconf get config xpath parent"
expecteof "$clixon_netconf -qf $cfg" 0 "$(cat $tmp)" '^<rpc-reply><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth/0/0</name><enabled>true</enabled></interface><interface><name>eth1</name><enabled>true</enabled><ipv4><enabled>true</enabled><forwarding>false</forwarding><address><ip>9.2.3.4</ip><prefix-length>24</prefix-length></address></ipv4></interface></interfaces></data></rpc-reply>]]>]]>$'

new "netconf validate missing type"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error>"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get empty config2"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data/></rpc-reply>]]>]]>$"

new "netconf edit extra xml"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><extra/></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><rpc-error>"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf edit config eth1"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth1</name><type>ex:eth</type></interface></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf edit config merge"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth2</name><type>ex:eth</type></interface></interfaces></config><default-operation>merge</default-operation></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf edit ampersand encoding(<&): name:'eth&' type:'t<>'"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth&amp;</name><type>t&lt;&gt;</type></interface></interfaces></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf get replaced config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth&amp;</name><type>t&lt;&gt;</type><enabled>true</enabled></interface><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>eth2</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$'

new "cli show configuration eth& - encoding tests"
expectfn "$clixon_cli -1 -f $cfg show conf cli" 0 "interfaces interface eth& type t<>
interfaces interface eth& enabled true"

new "netconf edit CDATA"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth/0/0</name><type>ex:eth</type><description><![CDATA[myeth&]]></description></interface></interfaces></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#new "netconf get CDATA"
#expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/interfaces/interface[name='eth/0/0']/description\" /></get-config></rpc>]]>]]>' '<rpc-reply><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth/0/0</name><description><![CDATA[myeth&]]></description><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf edit state operation should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><state xmlns="urn:example:clixon"><op>42</op></state></config></edit-config></rpc>]]>]]>' "^<rpc-reply><rpc-error><error-type>protocol</error-type><error-tag>invalid-value</error-tag>"

new "netconf get state operation"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get><filter type=\"xpath\" select=\"/state\"/></get></rpc>]]>]]>" '^<rpc-reply><data><state xmlns="urn:example:clixon"><op>42</op><op>41</op><op>43</op></state></data></rpc-reply>]]>]]>$'

new "netconf lock/unlock"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><lock><target><candidate/></target></lock></rpc>]]>]]><rpc><unlock><target><candidate/></target></unlock></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]><rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf lock/lock"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><lock><target><candidate/></target></lock></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf lock" 
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><lock><target><candidate/></target></lock></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "close-session"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><close-session/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# XXX NOTE that this does not actually kill a running session - and may even kill some random process,...
new "kill-session"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><kill-session><session-id>44</session-id></kill-session></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "copy startup"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><copy-config><target><startup/></target><source><candidate/></source></copy-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get startup"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><startup/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$'

new "netconf delete startup"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><delete-config><target><startup/></target></delete-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf check empty startup"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><startup/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data/></rpc-reply>]]>]]>$"

new "netconf example rpc"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><example xmlns="urn:example:clixon"><x>42</x></example></rpc>]]>]]>' '^<rpc-reply><x xmlns="urn:example:clixon">42</x><y xmlns="urn:example:clixon">42</y></rpc-reply>]]>]]>$'

new "netconf empty rpc"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><empty xmlns="urn:example:clixon"/></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf client-side rpc"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><client-rpc xmlns="urn:example:clixon"><x>val42</x></client-rpc></rpc>]]>]]>' '^<rpc-reply><x xmlns="urn:example:clixon">val42</x></rpc-reply>]]>]]>$'

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
