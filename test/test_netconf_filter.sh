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
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
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

new "waiting"
wait_backend

new "Add two entries"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y><y><a>2</a><b>2</b></y></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "wrong filter type"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get><filter type='foo'><x xmlns='urn:example:filter'><y><a>1</a></y></x></filter></get></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-tag>operation-failed</error-tag><error-type>applicatio</error-type><error-severity>error</error-severity><error-message>filter type not supported</error-message><error-info>type</error-info></rpc-error></rpc-reply>]]>]]>$"

new "get-config subtree one"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get-config><source><running/></source><filter type='subtree'><x xmlns='urn:example:filter'><y><a>1</a></y></x></filter></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>]]>]]>$"

new "get subtree one"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get><filter type='subtree'><x xmlns='urn:example:filter'><y><a>1</a></y></x></filter></get></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>]]>]]>$"

new "get-config xpath one"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[fi:a='1']\" xmlns:fi='urn:example:filter' /></get></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>]]>]]>$"

new "get xpath one"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get><filter type='xpath' select=\"/fi:x/fi:y[fi:a='1']\" xmlns:fi='urn:example:filter' /></get></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:filter\"><y><a>1</a><b>1</b></y></x></data></rpc-reply>]]>]]>$"

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
