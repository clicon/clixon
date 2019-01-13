#!/bin/bash
# Advanced union types and generated code
# and enum w values
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyang=$dir/type.yang
fyang2=$dir/example2.yang
fyang3=$dir/example3.yang

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
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
         enum "unbounded";
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
  import example3 { prefix ex3; }
  namespace "urn:example:example2";
  prefix ex2;
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

new "test params: -f $cfg -y $fyang"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg -y $fyang"
    sudo $clixon_backend -s init -f $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "cli set transitive string"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c talle x" 0 "^$"

new "cli set transitive union"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c ulle 33" 0 "^$"

new "cli set transitive union error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c ulle kalle" 255 ""

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
