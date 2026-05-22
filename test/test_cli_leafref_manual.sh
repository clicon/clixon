#!/usr/bin/env bash
# Test expand_dbvar leafref-refer behavior in manually crafted clispec.
#
# Verifies that:
#   1. Without leafref-refer label (default): expand_dbvar returns existing
#      stored values (the lref leaf-list itself).
#   2. With leafref-refer label (opt-in): expand_dbvar follows the leafref
#      and returns values from the referred node (parameter/name).
#
# This is the counterpart of the autocli case where the generator sets
# leafref-refer automatically for leafref/union typed variables.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang
clidir=$dir/clidir

if [ ! -d $clidir ]; then
    mkdir $clidir
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# YANG: a list of named parameters, and a leaf-list of leafrefs into that list.
cat <<EOF > $fyang
module clixon-example {
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  list parameter {
    key name;
    leaf name {
      type string;
    }
  }
  leaf-list lref {
    type leafref {
      path "/ex:parameter/ex:name";
    }
  }
}
EOF

# Manually crafted clispec with two expand_dbvar commands:
#   set lref:    leafref-refer label present  -> follows leafref -> completes to parameter names
#   delete lref: leafref-refer label absent   -> uses stored values -> completes to existing lref values
cat <<EOF > $clidir/cli1.cli
CLICON_MODE="example";
set lref (<val:string>|<val:string expand_dbvar("candidate","/clixon-example:lref","leafref-refer")>),
    cli_set("/clixon-example:lref");
delete lref (<val:string>|<val:string expand_dbvar("candidate","/clixon-example:lref")>),
    cli_del("/clixon-example:lref");
show configuration, cli_show_auto_mode("candidate", "xml", true, false);
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

# Populate: two parameter entries (the referred nodes)
new "Add parameter alice"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><parameter xmlns=\"urn:example:clixon\"><name>alice</name></parameter></config></edit-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add parameter bob"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><parameter xmlns=\"urn:example:clixon\"><name>bob</name></parameter></config></edit-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Commit parameters"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Test 1: set lref ? has leafref-refer -> should expand to referred parameter names (alice, bob)
new "set lref expands to referred parameter names (leafref-refer)"
expectpart "$(echo "set lref ?" | $clixon_cli -f $cfg 2>&1)" 0 "alice" "bob"

# Add one lref value so delete can expand to it
new "Add lref alice via CLI"
expectpart "$($clixon_cli -1 -f $cfg set lref alice)" 0 "^$"

new "Commit lref"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Test 2: delete lref ? has no leafref-refer -> should expand to existing stored lref values (alice only)
new "delete lref expands to existing stored values only (no leafref-refer)"
expectpart "$(echo "delete lref ?" | $clixon_cli -f $cfg 2>&1)" 0 "alice" --not-- "bob"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
