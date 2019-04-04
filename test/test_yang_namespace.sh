#!/bin/bash
# Test two modules example1 and example2 with overlapping statements x.
# x is leaf in example1 and list on example2.
# Test netconf and restconf
# BTW, this is not supported in generated CLI

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang1=$dir/example1.yang
fyang2=$dir/example2.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF


cat <<EOF > $fyang1
module example1{
   yang-version 1.1;
   prefix ex1;
   namespace "urn:example:clixon1";
   leaf x{
     type int32;
   }
}
EOF

# For testing namespaces -
# x.y is different type. Here it is string whereas in fyang1 it is list.
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

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
start_restconf -f $cfg 

new "waiting"
sleep $RCWAIT

new "netconf set x in example1"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon1">42</x></config></edit-config></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><ok/></rpc-reply>]]>]]>$'

new "netconf get config example1"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><x xmlns="urn:example:clixon1">42</x></data></rpc-reply>]]>]]>$'

new "netconf set x in example2"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon2"><y>99</y></x></config></edit-config></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><ok/></rpc-reply>]]>]]>$'

new "netconf get config example1 and example2"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><x xmlns="urn:example:clixon1">42</x><x xmlns="urn:example:clixon2"><y>99</y></x></data></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "restconf set x in example1"
expecteq "$(curl -s -X POST -d '{"example1:x":42}' http://localhost/restconf/data)" 0 ''

new "restconf get config example1"
expecteq "$(curl -s -X GET http://localhost/restconf/data/example1:x)" 0 '{"example1:x": 42}
'

new "restconf set x in example2"
expecteq "$(curl -s -X POST -d '{"example2:x":{"y":99}}' http://localhost/restconf/data)" 0 ''

# XXX GET ../example1:x is translated to select=/x which gets both example1&2
#new "restconf get config example1"
#expecteq "$(curl -s -X GET http://localhost/restconf/data/example1:x)" 0 '{"example1:x": 42}
#'

# XXX GET ../example2:x is translated to select=/x which gets both example1&2
#new "restconf get config example2"
#expecteq "$(curl -s -X GET http://localhost/restconf/data/example2:x)" 0 '{"example2:x": {"y":42}}
#'

new "restconf get config example1 and example2"
ret=$(curl -s -X GET http://localhost/restconf/data)
expect='"example1:x": 42,"example2:x": {"y": 99}'
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "Kill restconf daemon"
stop_restconf 

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
sudo pkill -u root -f clixon_backend

rm -rf $dir
