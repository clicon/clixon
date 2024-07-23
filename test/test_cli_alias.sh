#!/usr/bin/env bash
# Tests for CLI simple alias
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example.yang
clidir=$dir/cli
fin=$dir/alias.cli

if [ -d $clidir ]; then
    rm -rf $clidir/*
else
    mkdir $clidir
fi

# Generate autocli for these modules
AUTOCLI=$(autocli_config ${APPNAME}\* kw-nokey false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  ${AUTOCLI}
</clixon-config>
EOF

cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";

set @datamodel, cli_auto_set();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del();
      all("Delete whole candidate configuration"), delete_all("candidate");
}
show("Show a particular state of the system") {
   configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", false, false);{
     json,      cli_show_auto_mode("candidate", "json", false, false);
   }
   alias, cli_alias_show();
}
alias("Define alias function") <name:string>("Name of alias") <command:rest>("Alias commands"), cli_alias_add("name", "command");
aliasref("Define alias function using completion") <name:string>("Name of alias") @example, cli_aliasref_add("name");
EOF

cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;
  container table{
    list parameter{
      key name;
      leaf name{
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

new "Set alias"
expectpart "$($clixon_cli -1f $cfg alias newcmd show config)" 0 "^$"

cat <<EOF > $fin
set table parameter x
alias newcmd show config
newcmd
EOF

new "Load and check alias"
expectpart "$(cat $fin | $clixon_cli -f $cfg)" 0 "<table xmlns=\"urn:example:clixon\"><parameter><name>x</name></parameter></table>"

cat <<EOF > $fin
alias newcmd show config
alias newcmd show config json
newcmd
EOF

new "Replace alias"
expectpart "$(cat $fin | $clixon_cli -f $cfg)" 0 '{"example:table":{"parameter":\[{"name":"x"}\]}}' --not-- "<table xmlns=\"urn:example:clixon\"><parameter><name>x</name></parameter></table>"

cat <<EOF > $fin
alias cmd1 show config
alias cmd2 show config json
show alias
EOF

new "show alias"
expectpart "$(cat $fin | $clixon_cli -f $cfg)" 0 "cmd1: show config" "cmd2: show config json"

cat <<EOF > $fin
aliasref newcmd show config
newcmd
EOF

new "Load and check alias reference"
expectpart "$(cat $fin | $clixon_cli -f $cfg)" 0 "<table xmlns=\"urn:example:clixon\"><parameter><name>x</name></parameter></table>"

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
