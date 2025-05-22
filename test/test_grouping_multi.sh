#!/usr/bin/env bash
# Tests multiple level groupings
# See https://github.com/clicon/clixon/issues/572

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example.yang

# XXX try -E?
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
</clixon-config>
EOF

cat <<EOF > $dir/example.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";

# Autocli syntax tree operations
edit @datamodel, cli_auto_edit("datamodel");
up, cli_auto_up("datamodel");
top, cli_auto_top("datamodel");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
commit("Commit the changes"), cli_commit();
validate("Validate changes"), cli_validate();
delete("Delete a configuration item") {
      @datamodel, @add:leafref-no-refer, cli_auto_del();
      all("Delete whole candidate configuration"), delete_all("candidate");
}
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", false, false);
}
EOF

# Yang specs must be here first for backend. But then the specs are changed but just for CLI
# Annotate original Yang spec example  directly
# First annotate /table/parameter
# Had a problem with unknown in grouping -> test uses uses/grouping
cat <<EOF > $fyang
module example {
   namespace "urn:example:clixon";
   prefix ex;
   grouping L0-group {
      leaf L0{
         type string;
      }
   }
   grouping L1-group {
      list L1 {
         key x;
         leaf x {
            type uint32;
         }
         uses L0-group {
            when 'x=42';
//            when 'false';
         }
      }
   }
   container L2x {
      description "Two-level";
      list L1 {
         key x;
         leaf x {
            type uint32;
         }
         uses L0-group {
            when 'x=42';
//            when 'false';
         }
      }
   }
   container L2y {
      description "Three levels";
      uses L1-group;
   }
   grouping L2-group {
      container L2 {
         uses L1-group;
      }
   }
   container L3 {
      description "Four levels";
      uses L2-group;
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

new "CLI: L2 17, expect fail"
expectpart "$($clixon_cli -f $cfg -1 set L2x L1 17 L0 x 2>&1)" 255 "Node 'L0' tagged with 'when' condition 'x=42' in module 'example'"

new "CLI: L2 42, expect ok"
expectpart "$($clixon_cli -f $cfg -1 set L2x L1 42 L0 x 2>&1)" 0 ""

new "NETCONF: L2x, expect fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><L2x xmlns=\"urn:example:clixon\"><L1><x>17</x><L0>x</L0></L1></L2x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>L0</bad-element></error-info><error-severity>error</error-severity><error-message>Node 'L0' tagged with 'when' condition 'x=42' in module 'example' evaluates to false in edit-config operation (see RFC 7950 Sec 8.3.2)</error-message></rpc-error></rpc-reply>"

new "NETCONF: L2x, expect ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><L2x xmlns=\"urn:example:clixon\"><L1><x>42</x><L0>x</L0></L1></L2x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "NETCONF validate, expect ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "L2y grouping, expect fail"
expectpart "$($clixon_cli -f $cfg -1 set L2y L1 17 L0 x 2>&1)" 255 "Node 'L0' tagged with 'when' condition 'x=42' in module 'example'"

new "L2y grouping, expect ok"
expectpart "$($clixon_cli -f $cfg -1 set L2y L1 42 L0 x 2>&1)" 0 ""

new "NETCONF: L2y, expect fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><L2y xmlns=\"urn:example:clixon\"><L1><x>17</x><L0>x</L0></L1></L2y></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>L0</bad-element></error-info><error-severity>error</error-severity><error-message>Node 'L0' tagged with 'when' condition 'x=42' in module 'example' evaluates to false in edit-config operation (see RFC 7950 Sec 8.3.2)</error-message></rpc-error></rpc-reply>"

new "NETCONF: L2y, expect ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><L2y xmlns=\"urn:example:clixon\"><L1><x>42</x><L0>x</L0></L1></L2y></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "L3, expect fail"
expectpart "$($clixon_cli -f $cfg -1 set L3 L2 L1 17 L0 x 2>&1)" 255 ""

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
