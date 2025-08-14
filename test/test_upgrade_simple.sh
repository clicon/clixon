#!/usr/bin/env bash
# A very simple case - Error in this detected by mgsmith@netgate
# Enable modstate and save running on a simple system without upgrade callback
# Upgrade yang revision, but no other (upgrade) changes
# Then start from running with modstate enabled and the new revision

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=simple

cfg=$dir/conf_yang.xml

# Create configuration
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>/usr/local/etc/clixon.xml</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>$APPNAME</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLI_MODE>hello</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/hello/clispec</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/hello.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/hello.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <CLICON_XMLDB_UPGRADE_CHECKOLD>false</CLICON_XMLDB_UPGRADE_CHECKOLD>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
</clixon-config>
EOF

cat <<EOF > $dir/$APPNAME.yang
module $APPNAME {
    yang-version 1.1;
    namespace "urn:example:simple";
    prefix he;
    revision 2019-04-17 {
        description
            "Clixon hello world example";
    }
    container hello{
        container world{
            presence true;
        }
    }
}
EOF

new "test params: -f $cfg"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend 1"
wait_backend

new "add hello world (with modstate)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><hello xmlns=\"urn:example:simple\"><world/></hello></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# race condition where backend is killed before flushed to disk
sleep $DEMSLEEP

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

# Now add a new yang for hello
cat <<EOF > $dir/$APPNAME.yang
module $APPNAME {
    yang-version 1.1;
    namespace "urn:example:simple";
    prefix he;
    revision 2020-01-01 {
        description
            "Test new revision";
    }
    revision 2019-04-17 {
        description
            "Clixon hello world example";
    }
    container hello{
        container world{
            presence true;
        }
    }
}
EOF

# Now start again from running with modstate enabled and new revision
if [ $BE -ne 0 ]; then
    new "start backend -s running -f $cfg"
    start_backend -s running -f $cfg
fi

new "wait backend 2"
wait_backend

new "netconf get config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><hello xmlns=\"urn:example:simple\"><world/></hello></data></rpc-reply>"

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
