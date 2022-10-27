#!/usr/bin/env bash
# Yang list unique tests
# Use example in RFC7890 7.8.3.1, modify fields and also test a variant with
# a single unique identifier (rfc example has two)
# The test adds the rfc conf that fails, then one that passes, then makes add
# to fail it and then del to pass it.
# Then makes a fail / pass test on the single field case
# Last, a complex unsorted list with several sub-elements.

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
  container c{
     leaf a{
       type string;
     }
     list server {
       description "RFC7950 7.8.3.1";
       key "name";
       unique "ip port";
       leaf name {
         type string;
       }
       leaf ip {
         type string;
       }
       leaf port {
         type uint16;
       }
     }
     list other {
       description "random inserted data";
       key a;
       leaf a{
         type string;
       }
     }
     list single {
       description "similar with just a single unique field";
       key "name";
       unique "ip";
       leaf name {
         type string;
       }
       leaf ip {
         type string;
       }
     }
     leaf b{
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

# RFC test two-field caes
new "Add not valid example"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\"><server>
       <name>smtp</name>
       <ip>192.0.2.1</ip>
       <port>25</port>
     </server>
     <server>
       <name>http</name>
       <ip>192.0.2.1</ip>
       <port>25</port>
     </server>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/rpc/edit-config/config/c/server[name=\"http\"]/ip</non-unique><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/rpc/edit-config/config/c/server[name=\"http\"]/port</non-unique></error-info></rpc-error></rpc-reply>"

new "Add valid example"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\"><server>
       <name>smtp</name>
       <ip>192.0.2.1</ip>
       <port>25</port>
     </server>
     <server>
       <name>http</name>
       <ip>192.0.2.1</ip>
     </server>
     <server>
       <name>ftp</name>
       <ip>192.0.2.1</ip>
     </server>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "make it invalid by adding port to ftp entry"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config><c xmlns=\"urn:example:clixon\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><server><name>ftp</name><port nc:operation=\"create\">25</port></server>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate (should fail)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/c/server[name=\"smtp\"]/ip</non-unique><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/c/server[name=\"smtp\"]/port</non-unique></error-info></rpc-error></rpc-reply>"

new "make it valid by deleting port from smtp entry"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config><c xmlns=\"urn:example:clixon\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><server><name>smtp</name><port nc:operation=\"delete\">25</port></server>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Then test single-field case
new "Add not valid example: 1st single"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\"><single>
       <name>smtp</name>
       <ip>192.0.2.1</ip>
     </single>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add not valid example: 2nd single"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>merge</default-operation><config><c xmlns=\"urn:example:clixon\">
     <single>
       <name>http</name>
       <ip>192.0.2.1</ip>
     </single>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate (should fail) 2nd"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/c/single[name=\"smtp\"]/ip</non-unique></error-info></rpc-error></rpc-reply>"

new "make valid by replacing IP of http entry"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config><c xmlns=\"urn:example:clixon\"><single><name>http</name><ip>178.23.34.1</ip></single>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Then test composite case (detect duplicates among other elements)
# and also unordered

new "Add not valid example3"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
     <b>other</b>
     <single>
       <name>smtp</name>
       <ip>192.0.2.1</ip>
     </single>
     <a>other</a>
     <server>
       <name>smtp</name>
       <ip>192.0.2.1</ip>
       <port>25</port>
     </server>
     <single>
       <name>http</name>
       <ip>192.0.2.1</ip>
     </single>
     <other><a>xx</a></other>
     <server>
       <name>http</name>
       <ip>192.0.2.1</ip>
       <port>25</port>
     </server>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate (should fail) example3"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity><error-info><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/c/server[name=\"smtp\"]/ip</non-unique><non-unique xmlns=\"urn:ietf:params:xml:ns:yang:1\">/c/server[name=\"smtp\"]/port</non-unique></error-info></rpc-error></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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
