#!/usr/bin/env bash
# autocli extension strict expansion
# See https://github.com/clicon/clixon/issues/163
# test is: add a couple of expansion alternatives, ensure cli cannot select any oother option

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

# Use yang in example

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
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
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
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
show("Show a particular state of the system")
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "xml", false, false);
EOF

# Yang specs must be here first for backend. But then the specs are changed but just for CLI
# Annotate original Yang spec example  directly
# First annotate /table/parameter 
# Had a problem with unknown in grouping -> test uses uses/grouping
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
        autocli:strict-expand;
        type string;
      }
      leaf value{
        type string;
      }
      leaf value2{
        autocli:strict-expand;
        type string;
      }
      leaf-list value3{
         autocli:strict-expand;
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

# The list
new "Add three list options"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>opta</name><value>42</value></parameter><parameter><name>optb</name><value>43</value></parameter><parameter><name>optc</name><value>44</value></parameter></table></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "show config"
expectpart "$($clixon_cli -1 -f $cfg show conf)" 0 "<table xmlns=\"urn:example:clixon\"><parameter><name>opta</name><value>42</value></parameter><parameter><name>optb</name><value>43</value></parameter><parameter><name>optc</name><value>44</value></parameter></table>"

new "Check query"
expectpart "$(echo "set table parameter ?" | $clixon_cli -f $cfg 2>&1)" 0 opta optb optc --not-- '<name>'

new "Check completion"
expectpart "$(echo "set table parameter 	" | $clixon_cli -f $cfg 2>&1)" 0 opta optb optc --not-- '<name>'

# Leafs
new "Add leafs"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>opta</name><value>42</value><value2>43</value2><value3>44</value3></parameter></table></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "show config leafs"
expectpart "$($clixon_cli -1 -f $cfg show conf)" 0 "<table xmlns=\"urn:example:clixon\"><parameter><name>opta</name><value>42</value><value2>43</value2><value3>44</value3></parameter><parameter><name>optb</name><value>43</value></parameter><parameter><name>optc</name><value>44</value></parameter></table>"

new "Check query value"
expectpart "$(echo "set table parameter opta value ?" | $clixon_cli -f $cfg 2>&1)" 0 42 '<value>'

new "Check query value2"
expectpart "$(echo "set table parameter opta value2 ?" | $clixon_cli -f $cfg 2>&1)" 0 43 --not-- '<value>'

new "Check query value3"
expectpart "$(echo "set table parameter opta value3 ?" | $clixon_cli -f $cfg 2>&1)" 0 44 --not-- '<value>'

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
