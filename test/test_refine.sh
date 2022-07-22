#!/usr/bin/env bash
# yang refine
# See eg ietf-tls-server@2022-05-04.yang container certificate :
# 1. dual refine
# 2. refine argument is non-trivial descendant-schema-nodeid stretching over a choice/case
# 3. refine "str1" + "str2" i.e. split refine-arg-str
#
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
</clixon-config>
EOF

# This is the main module where the augment exists
cat <<EOF > $fyang
module clixon-example {
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;

   /* see ietf-keystore@2022-05-24.yang */
   grouping mygrouping {
    choice mykeystore {
      mandatory true;
      case local {
        container local-definition {
	  presence true;
	  leaf dummy1{
            type string;
	   default "foo1";	
	  }
        }
      }
      case keystore {
        container keystore-reference {
	  presence true;
	  leaf dummy2{
            type string;
	   default "bar1";	
	  }
        }
      }
    }
  }
  container certificate {
     description  "See ietf-tls-server@2022-05-24.yang";
     uses ex:mygrouping{
        refine "mykeystore/local/local-definition/dummy1" {
	   default "foo2";
        }
        refine "mykeystore/keystore/keystore-reference"
                   + "/dummy2" {
	   default "bar2";
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

new "Set local-definition"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><certificate xmlns=\"urn:example:clixon\"><local-definition/></certificate></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Get config expected foo2 refined default value"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><certificate xmlns=\"urn:example:clixon\"><local-definition><dummy1>foo2</dummy1></local-definition></certificate></data></rpc-reply>"

new "Set keystore-reference"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><certificate xmlns=\"urn:example:clixon\"><keystore-reference/></certificate></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Get config expected bar2 refined default value"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><certificate xmlns=\"urn:example:clixon\"><keystore-reference><dummy2>bar2</dummy2></keystore-reference></certificate></data></rpc-reply>"

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
