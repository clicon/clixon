#!/usr/bin/env bash
# Yang list unique tests using descendant schema node identifiers
# That is, not only direct descendants as the example in RFC7890 7.8.3.1

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exi{t 0; else return 0; fi

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
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Example (the list server part) from RFC7950 Sec 7.8.3.1 w changed types
cat <<EOF > $fyang
module unique{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix un;
  list outer{
     key name;
     leaf name{
        type string;
     }
     unique c/inner/value;
     container c{
        list inner{
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

RPC=$(cat<<EOF
<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>
    <outer xmlns="urn:example:clixon">
       <name>x</name><c>
          <inner><name>a</name><value>foo</value></inner>
          <inner><name>b</name><value>bar</value></inner>
       </c>
    </outer>
    <outer xmlns="urn:example:clixon">
       <name>y</name><c>
          <inner><name>a</name><value>fie</value></inner>
          <inner><name>b</name><value>fum</value></inner>
       </c>
    </outer>
</config></edit-config></rpc>
EOF
      )

# RFC test two-field cases
new "Add valid example"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "${RPC}" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

rpc="<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><outer xmlns=\"urn:example:clixon\"><name>x</name><c><inner><name>a</name><value>foo</value></inner><inner><name>b</name><value>foo</value></inner></c></outer><outer xmlns=\"urn:example:clixon\"><name>y</name><c><inner><name>a</name><value>fie</value></inner><inner><name>b</name><value>fum</value></inner></c></outer></config></edit-config></rpc>"

new "Add invalid example 1"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "${rpc}" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique>c/inner/value</non-unique></error-info></rpc-error></rpc-reply>"

rpc="<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><outer xmlns=\"urn:example:clixon\"><name>x</name><c><inner><name>a</name><value>foo</value></inner><inner><name>b</name><value>bar</value></inner></c></outer><outer xmlns=\"urn:example:clixon\"><name>y</name><c><inner><name>a</name><value>fie</value></inner><inner><name>b</name><value>bar</value></inner></c></outer></config></edit-config></rpc>"

new "Add invalid example 2"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "${rpc}" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique>c/inner/value</non-unique></error-info></rpc-error></rpc-reply>"

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

unset RPC

new "endtest"
endtest
