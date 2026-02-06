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

# Optional restconf config
RESTCONF_ENABLE=false
RESTCONF_FEATURE=""
RESTCONF_CFG=""
if [ $RC -ne 0 ]; then
    RESTCONF_CFG=$(restconf_config none false)
    if [ $? -eq 0 ]; then
        RESTCONF_ENABLE=true
        RESTCONF_FEATURE="<CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE>"
    fi
fi

cat <<EOF >$cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  $RESTCONF_FEATURE
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
  $RESTCONF_CFG
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

new "netconf validate candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

if $RESTCONF_ENABLE; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

if $RESTCONF_ENABLE; then
    new "wait restconf"
    wait_restconf

    new "restconf PATCH enabled-protocol identityref"
    expectpart "$(curl $CURLOPTS -X PATCH -H "Content-Type: application/yang-data+json" -d '{"openconfig-spanning-tree:config":{"enabled-protocol":["openconfig-spanning-tree-types:MSTP"]}}' $RCPROTO://localhost/restconf/data/openconfig-spanning-tree:stp/global/config)" 0 "HTTP/$HVER 204"

    new "restconf GET enabled-protocol"
    expectpart "$(curl $CURLOPTS -H "Accept: application/yang-data+json" -X GET $RCPROTO://localhost/restconf/data/openconfig-spanning-tree:stp/global/config/enabled-protocol)" 0 "HTTP/$HVER 200" "openconfig-spanning-tree-types:MSTP"

    new "Kill restconf daemon"
    stop_restconf
else
    echo "...skipped: restconf not enabled"
fi

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
