#!/usr/bin/env bash
# Test of yang construct:
#   uses . {
#      augment . {
#         when .

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang1=$dir/test1.yang
fyang2=$dir/test2.yang

# Generate autocli for these modules
AUTOCLI=$(autocli_config test\* kw-nokey false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>a:test</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang1</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  ${AUTOCLI}
</clixon-config>
EOF

# This is the lib function with the base container
cat <<EOF > $fyang1
module test1 {
    yang-version 1.1;
    namespace "http://www.test1.com/test1";
    prefix t1;
    import test2 { prefix t2; }

    container c {
      uses t2:mygroup {
         augment "table/parameter" {
           leaf value {
              type string;
              when "../name = 'x'"
                 + "or ../name = 'y'";
           }
         }
      }
    }
}
EOF

cat <<EOF > $fyang2
module test2 {
    yang-version 1.1;
    namespace "http://www.test2.com/test2";
    prefix t2;

    grouping mygroup {
      container table {
        list parameter{
            key name;
            leaf name{
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
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "cli set value x"
expectpart "$($clixon_cli -1 -f $cfg set c table parameter x value 98)" 0 ""

new "commit OK"
expectpart "$($clixon_cli -1 -f $cfg commit)" 0 ""

new "cli set value z"
expectpart "$($clixon_cli -1 -f $cfg set c table parameter z value 99)" 0 ""

new "commit Not OK"
expectpart "$($clixon_cli -1 -f $cfg commit 2>&1)" 255 "Failed WHEN condition of value in module test1"

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
