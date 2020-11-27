#!/usr/bin/env bash
# Tests for generating clispec from a yang subtree 

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

# Must be defined by a call: yang2cli_sub(h, ..., "datamodelexample", ...)
fin=$dir/in
cfg=$dir/conf_yang.xml
fyang=$dir/$APPNAME.yang
clidir=$dir/cli
if [ -d $clidir ]; then
    rm -rf $clidir/*
else
    mkdir $clidir
fi

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_GENMODEL>2</CLICON_CLI_GENMODEL>
  <CLICON_CLI_GENMODEL_TYPE>VARS</CLICON_CLI_GENMODEL_TYPE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

cat <<EOF > $fyang
module $APPNAME {
  namespace "urn:example:clixon";
  prefix ex;
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      leaf value{
        type string;
      }
      list index{
        key i;
	leaf i{
	  type string;
	}
      }
    }
  }
}
EOF

cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H> ";

# Manual command form where a sub-mode is created from @datamodel
# It gives: cvv eg:
# 0 : cmd = parameter 123
# 1 : string = "123"
enter <string>, cli_auto_sub_enter("datamodel", "/example:table/parameter=%s/index=%s/", "x");
leave, cli_auto_top("datamodel", "candidate");

# Autocli syntax tree operations
edit @datamodel, cli_auto_edit("interface");
up, cli_auto_up("datamodel");
top, cli_auto_top("datamodel");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "text", true, false);
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

    new "waiting"
    wait_backend
fi

cat <<EOF > $fin
enter a
leave
EOF
new "enter leave"
expectpart "$(cat $fin | $clixon_cli -f $cfg 2>&1)" 0 'enter a' 'leave' 

# XXX much more

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
