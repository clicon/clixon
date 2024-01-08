#!/usr/bin/env bash
# test for data creator attribute: add same object from sessions s1 and s2
# Restart and ensure attributes remain

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

cfg=$dir/conf.xml
fyang=$dir/clixon-example.yang

: ${clixon_util_xpath:=clixon_util_xpath}

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>$clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_NETCONF_CREATOR_ATTR>true</CLICON_NETCONF_CREATOR_ATTR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;

   container table {
      list parameter{
         key name;
         leaf name{
            type string;
         }
         leaf value{
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
    start_backend -s init -f $cfg
fi

new "wait backend 1"
wait_backend

conf="-d candidate -b $dir -y $fyang"

new "s1 add x"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>none</default-operation><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter nc:operation=\"create\" xmlns:nc=\"${BASENS}\" cl:creator=\"s1\" xmlns:cl=\"http://clicon.org/lib\"><name>x</name><value>foo</value></parameter></table></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "datastore get"
expectpart "$(sudo $clixon_util_xpath -f $dir/candidate_db -p /config/creators)" 0 "<creators xmlns=\"http://clicon.org/lib\"><creator><name>s1</name><path>/table/parameter\[name=\"x\"\]</path></creator></creators>"

new "rpc get-config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<table xmlns=\"urn:example:clixon\"><parameter><name>x</name><value>foo</value></parameter></table>" ""

# duplicate
new "s1 merge x"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>none</default-operation><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter nc:operation=\"merge\" xmlns:nc=\"${BASENS}\" cl:creator=\"s1\" xmlns:cl=\"http://clicon.org/lib\"><name>x</name><value>foo</value></parameter></table></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "datastore get"
expectpart "$(sudo $clixon_util_xpath -f $dir/candidate_db -p /config/creators)" 0 "<creators xmlns=\"http://clicon.org/lib\"><creator><name>s1</name><path>/table/parameter\[name=\"x\"\]</path></creator></creators>"

# New service
new "s2 merge x"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>none</default-operation><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter nc:operation=\"merge\" xmlns:nc=\"${BASENS}\" cl:creator=\"s2\" xmlns:cl=\"http://clicon.org/lib\"><name>x</name><value>foo</value></parameter></table></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "datastore get"
expectpart "$(sudo $clixon_util_xpath -f $dir/candidate_db -p /config/creators)" 0 "<creators xmlns=\"http://clicon.org/lib\"><creator><name>s1</name><path>/table/parameter\[name=\"x\"\]</path></creator><creator><name>s2</name><path>/table/parameter\[name=\"x\"\]</path></creator></creators>"

# New entry
new "s1 create y=bar"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>none</default-operation><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter nc:operation=\"create\" xmlns:nc=\"${BASENS}\" cl:creator=\"s1\" xmlns:cl=\"http://clicon.org/lib\"><name>y</name><value>bar</value></parameter></table></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "datastore get"
expectpart "$(sudo $clixon_util_xpath -f $dir/candidate_db -p /config/creators)" 0 "<creators xmlns=\"http://clicon.org/lib\"><creator><name>s1</name><path>/table/parameter\[name=\"x\"\]</path><path>/table/parameter\[name=\"y\"\]</path></creator><creator><name>s2</name><path>/table/parameter\[name=\"x\"\]</path></creator></creators>"

# To running
new "commit to running"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "datastore get running"
expectpart "$(sudo $clixon_util_xpath -f $dir/running_db -p /config/creators)" 0 "<creators xmlns=\"http://clicon.org/lib\"><creator><name>s1</name><path>/table/parameter\[name=\"x\"\]</path><path>/table/parameter\[name=\"y\"\]</path></creator><creator><name>s2</name><path>/table/parameter\[name=\"x\"\]</path></creator></creators>"

new "rpc get-config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<table xmlns=\"urn:example:clixon\"><parameter><name>x</name><value>foo</value></parameter><parameter><name>y</name><value>bar</value></parameter></table>" ""

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
fi

if [ $BE -ne 0 ]; then
    new "start backend -s running -f $cfg"
    start_backend -s running -f $cfg
fi

new "wait backend 2"
wait_backend

new "datastore get running"
expectpart "$(sudo $clixon_util_xpath -f $dir/running_db -p /config/creators)" 0 "<creators xmlns=\"http://clicon.org/lib\"><creator><name>s1</name><path>/table/parameter\[name=\"x\"\]</path><path>/table/parameter\[name=\"y\"\]</path></creator><creator><name>s2</name><path>/table/parameter\[name=\"x\"\]</path></creator></creators>"

new "rpc get-config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<table xmlns=\"urn:example:clixon\"><parameter><name>x</name><value>foo</value></parameter><parameter><name>y</name><value>bar</value></parameter></table>" ""

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
fi

rm -rf $dir

new "endtest"
endtest
