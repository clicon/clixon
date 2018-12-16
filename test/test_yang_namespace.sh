#!/bin/bash
# Yang specifics: multi-keys and empty type
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyang=$dir/example.yang
fyang2=$dir/example2.yang

#  <CLICON_YANG_DIR>/usr/local/share/$APPNAME/yang</CLICON_YANG_DIR>
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_YANG_DIR>/usr/local/share/$APPNAME/yang</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</config>
EOF

# For testing namespaces -
# x.y is different type. Here it is string whereas in fyang it is list.
#
cat <<EOF > $fyang2
module example2{
   yang-version 1.1;
   prefix ex2;
   namespace "urn:example:clixon2";
   container x {
     leaf y {
        type uint32;
     }
   }
}
EOF

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   prefix ex;
   namespace "urn:example:clixon";
   import ietf-routing {
        description "defines fib-route";
	prefix rt;
   }
   leaf x{
     type int32;
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
}
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend -s init -f $cfg"
    # start new backend
    sudo $clixon_backend -s init -f $cfg -D $DBG
    if [ $? -ne 0 ]; then
	err
    fi
fi



new "netconf xmlns module ex"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon">42</x></config></edit-config></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><ok/></rpc-reply>]]>]]>$'

new "netconf get config XXX xmlfn in return"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><x>42</x></data></rpc-reply>]]>]]>$"

new "netconf xmlns module ex2"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon2"><y>99</y></x></config></edit-config></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><ok/></rpc-reply>]]>]]>$'

new "netconf get config XXX xmlns"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><x>42</x><x><y>99</y></x></data></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf xmlns:ex"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:ex="urn:example:clixon"><edit-config><target><candidate/></target><config><ex:x>4422</ex:x></config></edit-config></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:ex="urn:example:clixon"><ok/></rpc-reply>]]>]]>$'

new "netconf get config XXX xmlns:ex"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><x>4422</x></data></rpc-reply>]]>]]>$"

new "netconf xmlns:ex2"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:ex2="urn:example:clixon2"><edit-config><target><candidate/></target><config><ex2:x><ex2:y>9999</ex2:y></ex2:x></config></edit-config></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:ex2="urn:example:clixon2"><ok/></rpc-reply>]]>]]>$'

new "netconf get config XXX xmlns:ex2"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><x>4422</x><x><y>9999</y></x></data></rpc-reply>]]>]]>$"

# rpc

if [ $BE -ne 0 ]; then
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
sudo pkill -u root -f clixon_backend

rm -rf $dir
