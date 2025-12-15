#!/usr/bin/env bash
# Verify openconfig-qos interface-ref leafref completion resolves oc-if namespace.
# Reproduces the CLI tab completion failure: "Prefix oc-if does not have an associated namespace"
# when typing: set qos interfaces interface eth1 interface-ref config interface <TAB>

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

OCDIR=$OPENCONFIG/release/models
OCQOS=$OPENCONFIG/release/models/qos/openconfig-qos.yang

cfg=$dir/openconfig_qos_interface_ref.xml

AUTOCLI=$(autocli_config "*" kw-nokey false)

cat <<EOF >$cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${OPENCONFIG}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$OCQOS</CLICON_YANG_MAIN_FILE>
  <CLICON_YANG_AUGMENT_ACCEPT_BROKEN>true</CLICON_YANG_AUGMENT_ACCEPT_BROKEN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
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

new "cli add oc-if interface eth1 target for leafref"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth1)" 0 "^$"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth1 config name eth1)" 0 "^$"

new "cli tab-complete qos interface-ref leafref"
expectpart "$(printf 'set qos interfaces interface eth1 interface-ref config interface \t\n' | $clixon_cli -f $cfg 2>&1)" 0 eth1 --not-- "Prefix oc-if does not have an associated namespace" "Database error"

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
