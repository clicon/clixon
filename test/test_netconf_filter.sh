#!/usr/bin/env bash
# Test netconf filter, subtree and xpath
# Note subtree namespaces not implemented

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/filter.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module filter{
  yang-version 1.1;
  namespace "urn:example:filter";
  prefix fi;
  container x{
     list y {
        key a;
        leaf a{
          type string;
        }
        leaf b{
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

new "wait backend"
wait_backend

new "Add two entries"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y><y><a>2</a><b>2</b></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "wrong filter type"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='foo'><x xmlns='urn:example:filter'><y><a>1</a></y></x></filter></get></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-tag>operation-failed</error-tag><error-type>applicatio</error-type><error-severity>error</error-severity><error-message>filter type not supported</error-message><error-info>type</error-info></rpc-error></rpc-reply>"

new "get-config subtree one (subtree implicit)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter><x xmlns='urn:example:filter'><y><a>1</a></y></x></filter></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>"

new "get subtree one (subtree implicit)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter><x xmlns='urn:example:filter'><y><a>1</a></y></x></filter></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>"

new "get-config subtree one"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><filter type='subtree'><x xmlns='urn:example:filter'><y><a>1</a></y></x></filter></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>"

new "get subtree one"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='subtree'><x xmlns='urn:example:filter'><y><a>1</a></y></x></filter></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>"

new "get-config xpath one"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[fi:a='1']\" xmlns:fi='urn:example:filter' /></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>"

new "get xpath one"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[fi:a='1']\" xmlns:fi='urn:example:filter' /></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>"

new "put more entries"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:filter\"><y><a>3</a><b>1345</b></y><y><a>4</a><b>2567</b></y><y><a>5</a></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "get xpath function not b=1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[not(fi:b='1')]\" xmlns:fi='urn:example:filter' /></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>2</a><b>2</b></y><y><a>3</a><b>1345</b></y><y><a>4</a><b>2567</b></y><y><a>5</a></y></x></data></rpc-reply>"

new "get xpath function not(b)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[not(fi:b)]\" xmlns:fi='urn:example:filter' /></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>5</a></y></x></data></rpc-reply>"

new "get xpath function contains"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[contains(fi:b,'2')]\" xmlns:fi='urn:example:filter' /></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>2</a><b>2</b></y><y><a>4</a><b>2567</b></y></x></data></rpc-reply>"

new "get xpath function not(contains(fib,2))"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[not(contains(fi:b,'2'))]\" xmlns:fi='urn:example:filter' /></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y><y><a>3</a><b>1345</b></y><y><a>5</a></y></x></data></rpc-reply>"

new "get xpath function or"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[fi:a='3' or fi:b='2567']\" xmlns:fi='urn:example:filter' /></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>3</a><b>1345</b></y><y><a>4</a><b>2567</b></y></x></data></rpc-reply>"

new "get xpath function and"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[not(fi:a='3') and contains(fi:b,'1')]\" xmlns:fi='urn:example:filter' /></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>"

new "get xpath function union"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[fi:b='1']|/fi:x/fi:y[fi:a='5']\" xmlns:fi='urn:example:filter' /></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y><y><a>5</a></y></x></data></rpc-reply>"

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
