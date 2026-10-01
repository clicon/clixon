#!/usr/bin/env bash
# Regression test: leafref tab-completion must not be corrupted when the
# current list entry's key value contains a literal '/'. (ie name='e/0')
# YANG below mirrors the reported case: a leaf inside a list entry is a
# leafref with a two-level "../../" path into a sibling top-level list.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang

AUTOCLI=$(autocli_config "*" kw-nokey false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  $AUTOCLI
</clixon-config>
EOF

# "scheduler-map" is a sibling top-level list (the leafref target).
# "interface" is a sibling top-level list whose entries have a leafref leaf
# pointing into scheduler-map via a two-level "../../" relative path, same
# shape as the reported YANG.
cat <<EOF > $fyang
module clixon-example {
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;

  list scheduler-map {
    key scheduler-map-name;
    leaf scheduler-map-name {
      type string;
    }
  }
  list interface {
    key name;
    leaf name {
      type string;
    }
    leaf scheduler-map-name {
      type leafref {
        path "../../scheduler-map/scheduler-map-name";
      }
    }
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

new "Add scheduler-map entries (leafref target)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><scheduler-map xmlns=\"urn:example:clixon\"><scheduler-map-name>map1</scheduler-map-name></scheduler-map><scheduler-map xmlns=\"urn:example:clixon\"><scheduler-map-name>map2</scheduler-map-name></scheduler-map></config></edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Commit scheduler-map entries"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# The key regression check: interface key value contains a literal '/'.
new "cli tab-complete leafref when list key value contains a literal /"
expectpart "$(echo "set interface ifp-0/1/4 scheduler-map-name ?" | $clixon_cli -f $cfg 2>&1)" 0 "map1" "map2" \
  --not-- "Failed to find YANG spec" --not-- "unknown-element" --not-- "rpc-error"

# Sanity: plain (no slash) key value must still complete correctly too,
new "cli tab-complete leafref when list key value has no slash (sanity)"
expectpart "$(echo "set interface eth0 scheduler-map-name ?" | $clixon_cli -f $cfg 2>&1)" 0 "map1" "map2" \
  --not-- "Failed to find YANG spec" --not-- "unknown-element" --not-- "rpc-error"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
