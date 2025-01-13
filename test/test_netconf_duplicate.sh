#!/usr/bin/env bash
# Detect duplicates in incoming edit-configs (not top-level)
# Both list and leaf-list
# See https://github.com/clicon/clixon-controller/issues/107
# Also, check CLICON_NETCONF_DUPLICATE_ALLOW

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
      list user {
         description "";
         ordered-by user;
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
      leaf-list buser{
         ordered-by user;
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

new "Add list entry"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>merge</default-operation><config><c xmlns=\"urn:example:clixon\" xmlns:nc=\"${BASENS}\">
     <server>
       <name>one</name>
       <value>foo</value>
     </server>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add duplicate list entries"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config><c xmlns=\"urn:example:clixon\" xmlns:nc=\"${BASENS}\">
     <server nc:operation=\"replace\">
       <name>one</name>
       <value>bar</value>
     </server>
     <server nc:operation=\"replace\">
       <name>one</name>
       <value>fie</value>
     </server>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/rpc/edit-config/config/c/server[name=\"one\"]/name</non-unique></error-info></rpc-error></rpc-reply>"

new "Add list with duplicate 2"
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

new "Add user sorted list with duplicate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
     <user>
       <name>one</name>
       <value>foo</value>
     </user>
     <user>
       <name>two</name>
       <value>bar</value>
     </user>
     <user>
       <name>one</name>
       <value>foo</value>
     </user>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/rpc/edit-config/config/c/user[name=\"one\"]/name</non-unique></error-info></rpc-error></rpc-reply>"

new "Add leaf-list with duplicate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
       <b>one</b>
       <b>two</b>
       <b>one</b>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/rpc/edit-config/config/c/b[.=\"one\"]/one</non-unique></error-info></rpc-error></rpc-reply>"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
fi

# Check CLICON_NETCONF_DUPLICATE_ALLOW
if [ $BE -ne 0 ]; then
    new "start backend -s init -f $cfg -o CLICON_NETCONF_DUPLICATE_ALLOW=true"
    # start new backend
    start_backend -s init -f $cfg -o CLICON_NETCONF_DUPLICATE_ALLOW=true
fi

new "Wait backend 2"
wait_backend

new "Add list with duplicate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
     <server>
       <name>bbb</name>
       <value>foo</value>
     </server>
     <server>
       <name>bbb</name>
       <value>bar</value>
     </server>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check no duplicates"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:clixon\"><server><name>bbb</name><value>bar</value></server></c></data></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add complex list with duplicate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
     <server>
       <name>aaa</name>
       <value>foo</value>
     </server>
     <server>
       <name>bbb</name>
       <value>foo</value>
     </server>
     <server>
       <name>ccc</name>
       <value>foo</value>
     </server>
     <server>
       <name>bbb</name>
       <value>bar</value>
     </server>
     <server>
       <name>ccc</name>
       <value>bar</value>
     </server>
     <server>
       <name>bbb</name>
       <value>fie</value>
     </server>
     <server>
       <name>ddd</name>
       <value>foo</value>
     </server>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check complex no duplicates"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:clixon\"><server><name>aaa</name><value>foo</value></server><server><name>bbb</name><value>fie</value></server><server><name>ccc</name><value>bar</value></server><server><name>ddd</name><value>foo</value></server></c></data></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add user sorted list with duplicate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
     <user>
       <name>aaa</name>
       <value>foo</value>
     </user>
     <user>
       <name>bbb</name>
       <value>foo</value>
     </user>
     <user>
       <name>ccc</name>
       <value>foo</value>
     </user>
     <user>
       <name>bbb</name>
       <value>bar</value>
     </user>
     <user>
       <name>ccc</name>
       <value>bar</value>
     </user>
     <user>
       <name>bbb</name>
       <value>fie</value>
     </user>
     <user>
       <name>ddd</name>
       <value>foo</value>
     </user>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check user sorted no duplicates"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:clixon\"><user><name>aaa</name><value>foo</value></user><user><name>ccc</name><value>bar</value></user><user><name>bbb</name><value>fie</value></user><user><name>ddd</name><value>foo</value></user></c></data></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leaf-list with dups"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
     <b>ccc</b>
     <b>aaa</b>
     <b>bbb</b>
     <b>aaa</b>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check leaf-list with dups"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:clixon\"><b>aaa</b><b>bbb</b><b>ccc</b></c></data></rpc-reply>"

new "leaf-list with dups ordered-by user"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
     <buser>CCC</buser>
     <buser>AAA</buser>
     <buser>BBB</buser>
     <buser>AAA</buser>
     <buser>AAA</buser>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:clixon\"><buser>CCC</buser><buser>BBB</buser><buser>AAA</buser></c></data></rpc-reply>"

new "list/leaf-list mix"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
     <b>ccc</b>
     <buser>CCC</buser>
     <user>
       <name>bbb</name>
       <value>foo</value>
     </user>
     <b>aaa</b>
     <buser>AAA</buser>
     <user>
       <name>aaa</name>
       <value>foo</value>
     </user>
     <b>bbb</b>
     <buser>BBB</buser>
     <user>
       <name>bbb</name>
       <value>foo</value>
     </user>
     <b>aaa</b>
     <buser>AAA</buser>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check mix"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:clixon\"><user><name>aaa</name><value>foo</value></user><user><name>bbb</name><value>foo</value></user><b>aaa</b><b>bbb</b><b>ccc</b><buser>CCC</buser><buser>BBB</buser><buser>AAA</buser></c></data></rpc-reply>"

new "Mix with empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
     <b>ccc</b>
     <buser>CCC</buser>
     <user>
       <name></name>
       <value>foo</value>
     </user>
     <b></b>
     <buser>AAA</buser>
     <user>
       <name>aaa</name>
       <value>foo</value>
     </user>
     <b>bbb</b>
     <buser>BBB</buser>
     <user>
       <name></name>
       <value>foo</value>
     </user>
     <b></b>
     <buser>AAA</buser>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check mix w empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:clixon\"><user><name>aaa</name><value>foo</value></user><user><name/><value>foo</value></user><b/><b>bbb</b><b>ccc</b><buser>CCC</buser><buser>BBB</buser><buser>AAA</buser></c></data></rpc-reply>"

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
