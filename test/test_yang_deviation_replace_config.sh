#!/usr/bin/env bash
# Yang deviate replace config/mandatory regression test
# See RFC 7950 5.6.3 and 7.20.3
#
# Regression test for a NULL-pointer dereference in yang_deviation()
# (lib/src/clixon_yang.c): a "deviate replace { config ...; }" statement
# targets the (possibly implicit) "config" sub-statement of the target
# node. If the target node has no *explicit* config sub-statement (the
# common case, since config is implicit-true/inherited by default),
# yang_find() legitimately returns NULL for it, but the code went on to
# unconditionally call ys_prune_self()/ys_free() on that NULL pointer,
# crashing the backend on startup with a SIGSEGV in yang_parent_get()
# (called from ys_prune_self()) while loading YANG.
#
# Also covers "deviate replace { mandatory ...; }" against a target with
# no explicit "mandatory" sub-statement (implicit default is "false" per
# RFC 7950 7.6.5): before the corresponding fix, this was spuriously
# rejected with a "node does not exist in target" error, since the
# "mandatory" property, like "config", always exists per RFC 7950 (with
# its default value) even when no explicit sub-statement is present.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = "$0" ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyangbase=$dir/example-base.yang
fyangdev=$dir/example-deviations.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Base module: "top" has no explicit config sub-statement (implicit
# config true, inherited), "leaf a" likewise has none. "leaf b" keeps
# "top" (a non-presence container) from being pruned

cat <<EOF > $fyangbase
module example-base{
    yang-version 1.1;
    prefix base;
    namespace "urn:example:base";
    container top {
        leaf a {
            type string;
        }
        leaf b {
            type string;
        }
    }
}
EOF

# Deviation module: "deviate replace { config ...; }" against nodes
# that have no explicit config sub-statement, and "deviate replace
# { mandatory ...; }" against a leaf with no explicit mandatory sub-stmt
cat <<EOF > $fyangdev
module example-deviations{
   yang-version 1.1;
   prefix ed;
   namespace "urn:example:deviations";
   import example-base {
         prefix base;
   }
   deviation /base:top {
      deviate replace {
         config true;
      }
   }
   deviation /base:top/base:a {
      deviate replace {
         config true;
         mandatory true;
      }
   }
}
EOF

if [ "$BE" -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf "$cfg"
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f "$cfg"
fi

new "wait backend"
wait_backend

new "Add leaf a and b (deviated node still usable after replace config)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:base\"><a>hello</a><b>world</b></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Delete leaf a (deviated mandatory true)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:base\"><a xmlns:nc=\"${BASENS}\" nc:operation=\"delete\"/></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate fail (leaf a is deviated mandatory)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>missing-element</error-tag><error-info><bad-element>a</bad-element></error-info><error-severity>error</error-severity><error-message>Missing mandatory XML a node"

if [ "$BE" -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    # kill backend
    stop_backend -f "$cfg"
fi

rm -rf "$dir"

new "endtest"
endtest
