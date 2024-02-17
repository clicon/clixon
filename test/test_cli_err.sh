#!/usr/bin/env bash
# Customixed error test

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

show config @datamodel, cli_show_auto("candidate", "cli");
example("Example callback") {
    <var:int32>("Just a random number"), mycallback("myarg");
    error {
      customized, myerror();     # Customized error message
      orig, cli_remove(); # Original
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

new "orig error"
expectpart "$($clixon_cli -1 -f $cfg -l n example error orig)" 255 "Config error: api-path syntax error " ": application invalid-value Invalid api-path:  (must start with '/')"

if [ ${LINKAGE} = dynamic ]; then
new "customized error"
expectpart "$($clixon_cli -1 -f $cfg -l n example error custom)" 255 "My new err-string"
fi

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

endtest

rm -rf $dir
