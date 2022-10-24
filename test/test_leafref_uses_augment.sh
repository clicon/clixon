#!/usr/bin/env bash
# leafref + augment + grouping, essentially test of default namespaces in augment+uses
# See also https://github.com/clicon/clixon/issues/308

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang1=$dir/test1.yang 
fyang2=$dir/test2.yang 
fyang3=$dir/test3.yang 

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
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
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
    import test3 { prefix t3; }

    grouping t1-group {
        container t1-con {
            leaf t1-a {
                type string;
            }        
            leaf t1-ref-a {
                type leafref {
                    path "../t1-a"; // This should have t1 namespace regardless of augment/uses
                }
            }
        }
    }
    container t1-con {
    }
    augment "/t1-con" {
        uses t1-group;
    }
    augment "/t3:t3-con" {
        uses t1:t1-group;
    }
    augment "/t3:t3-con" {
        uses t2:t2-group;
    }
}
EOF

cat <<EOF > $fyang2
module test2 {
    yang-version 1.1;
    namespace "http://www.test2.com/test2";
    prefix t2;

    grouping t2-group {
        container t2-con {
            leaf t2-a {
                type string;
            }        

            leaf t2-ref-a {
                type leafref {
                    path "../t2-a"; 
                }
            }
        }
    }
}
EOF

cat <<EOF > $fyang3
module test3 {
    yang-version 1.1;
    namespace "http://www.test3.com/test3";
    prefix t3;

    container t3-con {
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

new "cli set t1-con t1-con t1-a 123"
expectpart "$($clixon_cli -1 -f $cfg set t1-con t1-con t1-a 123)" 0 ""

new "cli set t1-con t1-con t1-ref-a 123"
expectpart "$($clixon_cli -1 -f $cfg set t1-con t1-con t1-ref-a 123)" 0 ""

new "cli validate"
expectpart "$($clixon_cli -1 -f $cfg validate)" 0 ""

new "cli discard"
expectpart "$($clixon_cli -1 -f $cfg discard)" 0 ""

new "cli set t3-con t1-con t1-a 123"
expectpart "$($clixon_cli -1 -f $cfg set t3-con t1-con t1-a 123)" 0 ""

new "cli set t3-con t1-con t1-ref-a 123"
expectpart "$($clixon_cli -1 -f $cfg set t3-con t1-con t1-ref-a 123)" 0 ""

new "cli validate"
expectpart "$($clixon_cli -1 -f $cfg validate)" 0 ""

new "cli discard"
expectpart "$($clixon_cli -1 -f $cfg discard)" 0 ""

new "cli set t3-con t2-con t2-a 123"
expectpart "$($clixon_cli -1 -f $cfg set t3-con t2-con t2-a 123)" 0 ""

new "cli set t3-con t2-con t2-ref-a 123"
expectpart "$($clixon_cli -1 -f $cfg set t3-con t2-con t2-ref-a 123)" 0 ""

new "cli validate"
expectpart "$($clixon_cli -1 -f $cfg validate)" 0 ""

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
