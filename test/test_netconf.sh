#!/bin/bash
# Test2: backend and netconf basic functionality
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyang=$dir/netconf.yang
tmp=$dir/tmp.x

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>/usr/local/share/$APPNAME/yang</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
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
    rpc empty {
    }
    list server {
       key name;
       leaf name {
         type string;
       }
       action reset {
       }
    }
    identity eth {
	 base if:interface-type;
    }

    rpc client-rpc {
	description "Example local client-side RPC that is processed by the
                     the netconf/restconf and not sent to the backend.
                     This is a clixon implementation detail: some rpc:s
                     are better processed by the client for API or perf reasons";
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
    container state {
       config false;
       description "state data for example application";
       leaf-list op {
          type string;
       }
    }
}
EOF

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err
fi
new "start backend  -s init -f $cfg -y $fyang"
# start new backend
sudo $clixon_backend -s init -f $cfg -y $fyang # -D 1
if [ $? -ne 0 ]; then
    err
fi

new "netconf hello"
expecteof "$clixon_netconf -f $cfg -y $fyang" 0 '<rpc message-id="101"><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability><capability>urn:ietf:params:netconf:capability:yang-library:1.0?revision="2016-06-21"&amp; module-set-id=42</capability></capabilities><session-id>[0-9]*</session-id></hello>]]>]]><rpc-reply message-id="101"><data/></rpc-reply>]]>]]>$'

new "netconf get-config"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc message-id="101"><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<rpc-reply message-id="101"><data/></rpc-reply>]]>]]>$'

new "Add subtree eth/0/0 using none which should not change anything"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><default-operation>none</default-operation><target><candidate/></target><config><interfaces><interface><name>eth/0/0</name></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Check nothing added"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc message-id="101"><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<rpc-reply message-id="101"><data/></rpc-reply>]]>]]>$'

new "Add subtree eth/0/0 using none and create which should add eth/0/0"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces><interface operation="create"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"


# Too many quotes, (single inside double inside single) need to fool bash
cat <<EOF > $tmp # new
<rpc><get-config><source><candidate/></source><filter type="xpath" select="/interfaces/interface[name='eth/0/0']"/></get-config></rpc>]]>]]>
EOF

new "Check eth/0/0 added using xpath"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "$(cat $tmp)" "^<rpc-reply><data><interfaces><interface><name>eth/0/0</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

new "Re-create same eth/0/0 which should generate error"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces><interface operation="create"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>' "^<rpc-reply><rpc-error>"

new "Delete eth/0/0 using none config"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces><interface operation="delete"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>'  "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Check deleted eth/0/0 (non-presence container)"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc message-id="101"><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<rpc-reply message-id="101"><data/></rpc-reply>]]>]]>$'

new "Re-Delete eth/0/0 using none should generate error"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><interfaces><interface operation="delete"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>'  "^<rpc-reply><rpc-error>"

new "netconf edit config"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><interfaces><interface><name>eth/0/0</name></interface><interface><name>eth1</name><enabled>true</enabled><ipv4><address><ip>9.2.3.4</ip><prefix-length>24</prefix-length></address></ipv4></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Too many quotes
cat <<EOF > $tmp # new
<rpc><get-config><source><candidate/></source><filter type="xpath" select="/interfaces/interface[name='eth1']/enabled"/></get-config></rpc>]]>]]>
EOF

new "netconf get config xpath"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "$(cat $tmp)" "^<rpc-reply><data><interfaces><interface><name>eth1</name><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

# Too many quotes
cat <<EOF > $tmp # new
<rpc><get-config><source><candidate/></source><filter type="xpath" select="/interfaces/interface[name='eth1']/enabled/../.."/></get-config></rpc>]]>]]>
EOF

new "netconf get config xpath parent"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "$(cat $tmp)" "^<rpc-reply><data><interfaces><interface><name>eth/0/0</name><enabled>true</enabled></interface><interface><name>eth1</name><enabled>true</enabled><ipv4><enabled>true</enabled><forwarding>false</forwarding><address><ip>9.2.3.4</ip><prefix-length>24</prefix-length></address></ipv4></interface></interfaces></data></rpc-reply>]]>]]>$"

new "netconf validate missing type"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error>"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get empty config2"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data/></rpc-reply>]]>]]>$"

new "netconf edit extra xml"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><interfaces><extra/></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply><rpc-error>"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf edit config eth1"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><interfaces><interface><name>eth1</name><type>ex:eth</type></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf edit config merge"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><interfaces><interface><name>eth2</name><type>ex:eth</type></interface></interfaces></config><default-operation>merge</default-operation></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf edit ampersand encoding(<&): name:'eth&' type:'t<>'"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><interfaces><interface><name>eth&amp; </name><type>t&lt; &gt; </type></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get replaced config"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><interfaces><interface><name>eth&amp; </name><type>t&lt; &gt; </type><enabled>true</enabled></interface><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>eth2</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

new "cli show configuration eth& - encoding tests"
expectfn "$clixon_cli -1 -f $cfg -y $fyang show conf cli" 0 "interfaces interface eth& type t<>
interfaces interface eth& enabled true"

new "netconf edit CDATA"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><interfaces><interface><name>eth/0/0</name><type>ex:eth</type><description><![CDATA[myeth&]]></description></interface></interfaces></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#new "netconf get CDATA"
#expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/interfaces/interface[name='eth/0/0']/description\" /></get-config></rpc>]]>]]>" "<rpc-reply><data><interfaces><interface><name>eth/0/0</name><description><![CDATA[myeth&]]></description><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>"


new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf edit state operation should fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><state><op>42</op></state></config></edit-config></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-tag>invalid-value</error-tag>"

new "netconf get state operation"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get><filter type=\"xpath\" select=\"/state\"/></get></rpc>]]>]]>" "^<rpc-reply><data><state><op>42</op></state></data></rpc-reply>]]>]]>$"

new "netconf lock/unlock"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><lock><target><candidate/></target></lock></rpc>]]>]]><rpc><unlock><target><candidate/></target></unlock></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]><rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf lock/lock"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><lock><target><candidate/></target></lock></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf lock" 
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><lock><target><candidate/></target></lock></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "close-session"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><close-session/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "kill-session"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><kill-session><session-id>44</session-id></kill-session></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "copy startup"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><copy-config><target><startup/></target><source><candidate/></source></copy-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get startup"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><startup/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><interfaces><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

new "netconf delete startup"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><delete-config><target><startup/></target></delete-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf check empty startup"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><startup/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data/></rpc-reply>]]>]]>$"

new "netconf rpc"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><rt:fib-route><routing-instance-name>ipv4</routing-instance-name><destination-address><address-family>ipv4</address-family></destination-address></rt:fib-route></rpc>]]>]]>" "^<rpc-reply><route><address-family>ipv4</address-family><next-hop><next-hop-list>"

new "netconf rpc without namespace"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><rt:fib-route><routing-instance-name>ipv4</routing-instance-name><destination-address><address-family>ipv4</address-family></destination-address></rt:fib-route></rpc>]]>]]>" "^<rpc-reply><route><address-family>ipv4</address-family><next-hop><next-hop-list>"

new "netconf empty rpc"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><ex:empty/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf client-side rpc"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><ex:client-rpc><request>example</request></ex:client-rpc></rpc>]]>]]>" "^<rpc-reply><result>ok</result></rpc-reply>]]>]]>$"

new "Kill backend"
# kill backend
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

# Check if still alive
pid=`pgrep clixon_backend`
if [ -n "$pid" ]; then
    sudo kill $pid
fi

rm -rf $dir
