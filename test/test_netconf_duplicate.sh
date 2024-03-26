#!/usr/bin/env bash
# Detect duplicates in incoming edit-configs (not top-level)
# Both list and leaf-list
# See https://github.com/clicon/clixon-controller/issues/107

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/unique.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Example (the list server part) from RFC7950 Sec 7.8.3.1 w changed types
cat <<EOF > $fyang
module unique{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix un;
  container c{
     presence "trigger"; // force presence container to trigger error
        list server {
           description "";
           key "name";
           leaf name {
              type string;
           }
           leaf value {
              type string;
           }
        }
        leaf-list b{
           type string;
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
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "Add list with duplicate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
     <server>
       <name>one</name>
       <value>foo</value>
     </server>
     <server>
       <name>one</name>
       <value>foo</value>
     </server>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/rpc/edit-config/config/c/server[name=\"one\"]/name</non-unique></error-info></rpc-error></rpc-reply>"

new "Add leaf-list with duplicate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
       <b>one</b>
       <b>two</b>
       <b>one</b>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/rpc/edit-config/config/c/b[.=\"one\"]/one</non-unique></error-info></rpc-error></rpc-reply>"

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
