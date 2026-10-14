#!/usr/bin/env bash
# Test the autocli "expand" extension: a YANG leaf can override the default
# expand_dbvar() CLI tab-completion callback with a custom one.
# Note  For a custom expand callback defined in a CLI frontend plugin (as opposed to one
# of clixon's own core libraries) to be found, that plugin must be dlopen'ed with RTLD_GLOBAL


# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example.yang
clidir=$dir/cli
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
  <CLICON_PLUGIN_DLOPEN_GLOBAL>true</CLICON_PLUGIN_DLOPEN_GLOBAL>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  ${AUTOCLI}
</clixon-config>
EOF

cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";

# Autocli syntax tree operations
edit @datamodel, cli_auto_edit("datamodel");
up, cli_auto_up("datamodel");
top, cli_auto_top("datamodel");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") {
      @datamodel, @add:leafref-no-refer, cli_auto_del();
      all("Delete whole candidate configuration"), delete_all("candidate");
}
show("Show a particular state of the system")
    configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", false, false);
EOF

cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;
  import clixon-autocli{
      prefix autocli;
  }
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      leaf value{
        type string;
      }
      leaf color{
        autocli:expand "cli_expand_fixed";
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

new "Add a list entry (no color set, candidate db has no 'red'/'green'/'blue' anywhere)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>opta</name><value>42</value></parameter></table></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "${DEFAULTHELLO}" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "show config: confirm no 'red'/'green'/'blue' value exists anywhere in candidate"
expectpart "$($clixon_cli -1 -f $cfg show conf)" 0 "<table xmlns=\"urn:example:clixon\"><parameter><name>opta</name><value>42</value></parameter></table>" \
  --not-- red green blue

new "Check plain leaf query (value): unaffected, still expand_dbvar (only existing instances, none here)"
expectpart "$(echo "set table parameter opta value ?" | $clixon_cli -f $cfg 2>&1)" 0 '<value>' --not-- red green blue

new "Check autocli:expand leaf query (color): custom callback offers fixed values not present in candidate db"
expectpart "$(echo "set table parameter opta color ?" | $clixon_cli -f $cfg 2>&1)" 0 red green blue

new "Check autocli:expand leaf completion (color), same fixed values via TAB"
expectpart "$(echo "set table parameter opta color 	" | $clixon_cli -f $cfg 2>&1)" 0 red green blue

new "Set color to one of the custom-expanded values and commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>opta</name><color>green</color></parameter></table></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit color"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "${DEFAULTHELLO}" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "show config with color set"
expectpart "$($clixon_cli -1 -f $cfg show conf)" 0 "<table xmlns=\"urn:example:clixon\"><parameter><name>opta</name><value>42</value><color>green</color></parameter></table>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
