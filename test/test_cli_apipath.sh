#!/usr/bin/env bash
# Tests for manually adding keys to cli set/merge/del callbacks including error handling
# Note only completed commands, not interactive expand/completion

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fyang=$dir/$APPNAME.yang
clidir=$dir/cli
if [ -d $clidir ]; then
    rm -rf $clidir/*
else
    mkdir $clidir
fi

# Generate autocli for these modules
AUTOCLI=$(autocli_config ${APPNAME} kw-all false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  ${AUTOCLI}
</clixon-config>
EOF

cat <<EOF > $fyang
module $APPNAME {
  namespace "urn:example:m";
  prefix m;
  container x {
    list m1 {
      key "a b";
      leaf a {
        type string;
      }
      leaf b {
        type string;
      }
      leaf c {
        type string;
      }
    }
  }
}
EOF

cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H> ";
CLICON_PLUGIN="example_cli";

# Positive
set x,cli_merge("/example:x");{
      a <a:string> b <b:string>,cli_merge("/example:x/m1=%s,%s/");{
         c <c:string>,cli_merge("/example:x/m1=%s,%s/c");
      }
      ax <a:string>("special case") c <c:string>,cli_merge("/example:x/m1=,%s/c");
}
# Negative
err x,cli_set("/example2:x");{
      a <a:string>,cli_merge("/example:x/m1=%s");
}

show config @datamodel, cli_show_auto("candidate", "cli");

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

# Positive tests
new "set x"
expectpart "$($clixon_cli -1 -f $cfg set x)" 0 ""

new "set x a b"
expectpart "$($clixon_cli -1 -f $cfg set x a 99 b 22)" 0 ""

new "set x a b c"
expectpart "$($clixon_cli -1 -f $cfg set x a 22 b 33 c 55)" 0 ""

new "show conf x"
expectpart "$($clixon_cli -1 -f $cfg show conf x)" 0 "x m1 a 22 b 33"

new "set conf x, special case comma"
expectpart "$($clixon_cli -1 -f $cfg set x ax 11 c 33)" 0 "^$"

new "show conf ax"
expectpart "$($clixon_cli -1 -f $cfg show conf x)" 0 "x m1 a (null) b 11 c 33"

new "set conf x, special case comma encoding"
expectpart "$($clixon_cli -1 -f $cfg set x ax 22/22 c 44)" 0 "^$"

new "show conf ax"
expectpart "$($clixon_cli -1 -f $cfg show conf x)" 0 "x m1 a (null) b 22/22 c 44"

# Negative tests
new "err x"
expectpart "$($clixon_cli -1 -f $cfg -l o err x)" 255 "Config error: api-path syntax error \"/example2:x\": application unknown-element No such yang module prefix <bad-element>example2</bad-element>: Invalid argument"

new "err x a"
expectpart "$($clixon_cli -1 -f $cfg -l o err x a 99)" 255 "Config error: api-path syntax error \"/example:x/m1=%s\": rpc malformed-message List key m1 length mismatch : Invalid argument"

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
