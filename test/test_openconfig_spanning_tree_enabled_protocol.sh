#!/usr/bin/env bash
# Verify openconfig-spanning-tree enabled-protocol identityref resolves oc-stp-types prefix.
# Reproduces CLI error: "prefix \"oc-stp-types\" has no associated namespace"

# Magic line must be first in script (see README.md)
s="$_"
. ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

new "openconfig"
if [ ! -d "$OPENCONFIG" ]; then
    #    err "Hmm Openconfig dir does not seem to exist, try git clone https://github.com/openconfig/public?"
    echo "...skipped: OPENCONFIG not set"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

OCSTP=$OPENCONFIG/release/models/stp/openconfig-spanning-tree.yang
cfg=$dir/openconfig_spanning_tree_enabled_protocol.xml

AUTOCLI=$(autocli_config "*" kw-nokey false)

cat <<EOF >$cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${OPENCONFIG}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$OCSTP</CLICON_YANG_MAIN_FILE>
  <CLICON_YANG_AUGMENT_ACCEPT_BROKEN>true</CLICON_YANG_AUGMENT_ACCEPT_BROKEN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  $AUTOCLI
</clixon-config>
EOF

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "cli set stp global enabled-protocol identityref"
expectpart "$($clixon_cli -1 -f $cfg set stp global config enabled-protocol oc-stp-types:MSTP 2>&1)" 0 "^$"

new "discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
