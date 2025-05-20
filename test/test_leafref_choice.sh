#!/usr/bin/env bash
# Yang leafref + choice test
# See https://github.com/clicon/clixon/issues/469

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/leafref.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example{
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    grouping fruits-and-flowers{
       list fruit {
          key "name";
          leaf name {
             type string;
          }
       }
       list flower {
          key "name";
          leaf name {
             type string;
          }
       }
       choice myChoice {
          description "Fruit or Flowers";
          case fruit {
             leaf fruit-name {
                description "Fruit name";
                type leafref {
                    path "../fruit/name";
                }
             }
          }
          case flower {
             leaf flower-name {
                description "Flower name";
                type leafref {
                    path "../flower/name";
                }
             }
          }
       }
   }
   container c {
      uses fruits-and-flowers;
   }
   uses fruits-and-flowers;
}
EOF

# Leafref and choice test
# Args:
# 1: prefix
function testrun()
{
    prefix=$1
    
    new "add fruit"
    expectpart "$($clixon_cli -1f $cfg set $prefix fruit apple)" 0 "^$"

    new "add fruit"
    expectpart "$($clixon_cli -1f $cfg set $prefix fruit orange)" 0 "^$"

    new "add flower"
    expectpart "$($clixon_cli -1f $cfg set $prefix flower daisy)" 0 "^$"

    new "add flower"
    expectpart "$($clixon_cli -1f $cfg set $prefix flower rose)" 0 "^$"

    new "commit"
    expectpart "$($clixon_cli -1f $cfg commit)" 0 "^$"

    new "expand fruit leafref"
    expectpart "$(echo "set $prefix fruit-name ?" | $clixon_cli -f $cfg 2> /dev/null)" 0 apple orange

    new "add fruit-name"
    expectpart "$($clixon_cli -1f $cfg set $prefix fruit-name apple)" 0 "^$"

    new "validate"
    expectpart "$($clixon_cli -1f $cfg validate)" 0 "^$"
}

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

new "Test top-level"
testrun ""

new "Test in container"
testrun "c "

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
