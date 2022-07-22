#!/usr/bin/env bash
# Advanced union types and generated code
# and enum w values

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/type.yang
fyang2=$dir/example2.yang
fyang3=$dir/example3.yang

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
</clixon-config>
EOF

# transitive type, exists in fyang3, referenced from fyang2, but not declared in fyang
cat <<EOF > $fyang3
module example3{
  prefix ex3;
  namespace "urn:example:example3";
  typedef u{
     type union {
       type int32{
          range "4..44";
       }
       type enumeration {
         enum unbounded;
       }
     }
  }
  typedef t{
    type string;
  }
}
EOF
cat <<EOF > $fyang2
module example2{
  namespace "urn:example:example2";
  prefix ex2;
  import example3 { prefix ex3; }
  grouping gr2 {
    leaf talle{
      type ex3:t;
    }
    leaf ulle{
      type ex3:u;
    }
  }
}
EOF
cat <<EOF > $fyang
module example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import example2 { prefix ex2; }
  container c{
    description "transitive type- exists in ex3";
    uses ex2:gr2;
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

new "cli set transitive string"
expectpart "$($clixon_cli -1f $cfg -l o set c talle x)" 0 "^$"

new "cli set transitive union"
expectpart "$($clixon_cli -1f $cfg -l o set c ulle 33)" 0 "^$"

new "cli set transitive union error"
expectpart "$($clixon_cli -1f $cfg -l o set c ulle kalle)" 255 "^CLI syntax error: \"set c ulle kalle\": 'kalle' is not a number$"

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
