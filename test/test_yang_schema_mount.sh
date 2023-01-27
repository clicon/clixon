#!/usr/bin/env bash
# Test for RFC8528 YANG Schema Mount
# Only if compiled with YANG_SCHEMA_MOUNT

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

if true; then # enable YANG_SCHEMA_MOUNT
    echo "...skipped: YANG_SCHEMA_MOUNT NYI"
    rm -rf $dir
    if [ -z "${CLIXON_YANG_PATCH}" -a "$s" = $0 ]; then exit 0; else return 0; fi
fi


APPNAME=example

cfg=$dir/conf_mount.xml
fyang=$dir/clixon-example.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${dir}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_NETCONF_MONITORING>true</CLICON_NETCONF_MONITORING>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import ietf-yang-schema-mount {
    prefix yangmnt;
  }
  container top{
    list root{
      key name;
      leaf name{
        type string;
      }
      yangmnt:mount-point "myroot"{
         description "Root for other yang models";
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

new "wait backend"
wait_backend

new "Add two mountpoints: x and y"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><root><name>x</name></root><root><name>y</name></root></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Retrieve schema-mounts with <get> Operation"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><schema-mounts xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-schema-mount\"></schema-mounts></filter></get></rpc>" "<rpc-reply $DEFAULTNS><data><schema-mounts xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-schema-mount\"><mount-point><module>clixon-example</module><label>myroot</label><config>true</config><inline/></mount-point></schema-mounts></data></rpc-reply>"

if true; then
new "get yang-lib at mountpoint"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><top xmlns=\"urn:example:clixon\"><root></root></top>></filter></get></rpc>" "<rpc-reply $DEFAULTNS><data><top xmlns=\"urn:example:clixon\"><root><name>x</name></root><root><name>y</name></root></top></data></rpc-reply>"
fi

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
