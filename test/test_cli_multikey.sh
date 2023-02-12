#!/usr/bin/env bash
# CLI test for multi-key lists
# Had bugs in duplicate detection

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fyang=$dir/$APPNAME.yang

# Generate autocli for these modules
AUTOCLI=$(autocli_config ${APPNAME} kw-all false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  ${AUTOCLI}
</clixon-config>
EOF

cat <<EOF > $fyang
module $APPNAME{
   yang-version 1.1;
   prefix ex;
   namespace "urn:example:clixon";
   container ex {
      list x{
         key "a b" ;
         leaf a {
            type string;
         }
         leaf b {
            type enumeration{
                enum v1;
                enum v2;
                enum v3;
            }
        }
      }
      list y{
         key "a b" ;
         ordered-by user;
         leaf a {
            type string;
         }
         leaf b {
            type enumeration{
                enum v1;
                enum v2;
                enum v3;
            }
        }
      }
      list z{
         key "a b" ;
         leaf a {
            type enumeration{
                enum v1;
                enum v2;
                enum v3;
            }
         }
         leaf b {
            type string;
        }
      }
   }
}
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "ordered by system"
new "set x 1 v1"
expectpart "$($clixon_cli -1 -f $cfg set ex x a 1 b v1)" 0 ""

new "set x 1 v2"
expectpart "$($clixon_cli -1 -f $cfg set ex x a 1 b v2)" 0 ""

new "set x 1 v3"
expectpart "$($clixon_cli -1 -f $cfg set ex x a 1 b v3)" 0 ""

new "set x 2 v1"
expectpart "$($clixon_cli -1 -f $cfg set ex x a 2 b v1)" 0 ""

new "set x 2 v2"
expectpart "$($clixon_cli -1 -f $cfg set ex x a 2 b v2)" 0 ""

new "set x 2 v3"
expectpart "$($clixon_cli -1 -f $cfg set ex x a 2 b v3)" 0 ""

new "set x 1 v2 again"
expectpart "$($clixon_cli -1 -f $cfg set ex x a 1 b v2)" 0 ""

new "show conf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><ex xmlns=\"urn:example:clixon\"><x><a>1</a><b>v1</b></x><x><a>1</a><b>v2</b></x><x><a>1</a><b>v3</b></x><x><a>2</a><b>v1</b></x><x><a>2</a><b>v2</b></x><x><a>2</a><b>v3</b></x></ex></data></rpc-reply>"

new "ordered-by user"
new "set y 1 v1"
expectpart "$($clixon_cli -1 -f $cfg set ex y a 1 b v1)" 0 ""

new "set y 2 v1"
expectpart "$($clixon_cli -1 -f $cfg set ex y a 2 b v1)" 0 ""

new "set y 1 v2"
expectpart "$($clixon_cli -1 -f $cfg set ex y a 1 b v2)" 0 ""

new "set y 1 v3"
expectpart "$($clixon_cli -1 -f $cfg set ex y a 1 b v3)" 0 ""

new "set y 2 v2"
expectpart "$($clixon_cli -1 -f $cfg set ex y a 2 b v2)" 0 ""

new "show conf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><ex xmlns=\"urn:example:clixon\"><x><a>1</a><b>v1</b></x><x><a>1</a><b>v2</b></x><x><a>1</a><b>v3</b></x><x><a>2</a><b>v1</b></x><x><a>2</a><b>v2</b></x><x><a>2</a><b>v3</b></x><y><a>1</a><b>v1</b></y><y><a>2</a><b>v1</b></y><y><a>1</a><b>v2</b></y><y><a>1</a><b>v3</b></y><y><a>2</a><b>v2</b></y></ex></data></rpc-reply>"

new "switch keys"
# see https://github.com/clicon/clixon/issues/417
new "set z 1 v1"
expectpart "$(echo "set ex z a v1 ?" | $clixon_cli -f $cfg 2> /dev/null)" 0 b --not-- "<cr>"

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
