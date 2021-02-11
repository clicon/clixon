#!/usr/bin/env bash
# Test augmenting in two steps and an augment accessing both
# ie aug2->aug1->base
# where the augment arg in aug2 is: "base:../aug1:..
# This occurs in several openconfig/yangmodels models, but does not work in clixon 4.7
#

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example-lib.yang       # base
fyang1=$dir/example-augment1.yang # first augment
fyang2=$dir/example-augment2.yang # second augment

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>a:test</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang2</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

# This is the lib function with the base container
cat <<EOF > $fyang
module example-lib {
  yang-version 1.1;
  namespace "urn:example:lib";
  revision "2019-03-04";
  prefix lib;
  container base-config {
  }
  /* No prefix */
  augment "/base-config" {
    description "no prefix";
    list parameter{
      key name;
      leaf name{
	type string;
      }
    }    
  }
}
EOF

# This is the first augment1
cat <<EOF > $fyang1
module example-augment1 {
  yang-version 1.1;
  namespace "urn:example:augment1";
  prefix aug1;
  revision "2020-09-25";
  import example-lib {
     prefix lib;
  }
  /* Augments config */
  augment "/lib:base-config/lib:parameter" {
    container aug1{
      description "Local augmented optional";
    }	  
  }
}
EOF

# This is the main module with second augment
cat <<EOF > $fyang2
module example-augment2 {
  yang-version 1.1;
  namespace "urn:example:augment2";
  prefix aug2;
  revision "2020-09-25";
  import example-lib {
     prefix lib;
  }
  import example-augment1 {
     prefix aug1;
  }
  /* Augments config */
  augment "/lib:base-config/lib:parameter/aug1:aug1" {
/*    when 'lib:name="foobar" and aug:aug1="foobar"'; */
    leaf aug2{
      description "Local augmented optional";
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
    start_backend -s init -f $cfg
fi
new "waiting"
wait_backend


new "get-config empty"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data/></rpc-reply>]]>]]>$"

if false; then
new "Add config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
