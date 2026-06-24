#!/usr/bin/env bash
# Minimal regression test for issue #681:
# MUST validation was silently skipped when an entire top-level list entry
# was deleted (find_target_equiv returned NULL at depth==0).
#
# Without the fix (return NULL in find_target_equiv):  E1 commit succeeds (BUG)
# With    the fix (return xttop):                      E1 commit fails    (OK)
#
# Usage: ./test_681.sh
#   Expected outcome: all 'new' steps pass (test exits 0)

s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example
cfg=$dir/conf.xml
fyang=$dir/test.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/backend.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Minimal YANG:
#   Top-level list 'instance' (key name, leaf active)
#   Top-level container 'user' with a leaf 'iref' that has a MUST
#   expression referencing instance[name=current()]/active.
#   Depth from iref: iref(0) -> user(1) -> <config>(2)
#   must depth = 2
cat <<EOF > $fyang
module test {
   yang-version 1.1;
   namespace "urn:example:test681";
   prefix t;
   revision 2024-01-01;

   list instance {
      key name;
      leaf name { type string; }
      leaf active { type string; }
   }

   container user {
      leaf iref {
         type string;
         must "../../t:instance[t:name=current()]/t:active = 'true'" {
            error-message "Referenced instance must have active=true";
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
    new "start backend"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

# ---------------------------------------------------------------------------
# Setup: create instance[blue]/active=true and user/iref=blue
#        Commit so this becomes the running config.
# ---------------------------------------------------------------------------
new "Setup: create instance[blue] and user/iref=blue"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <instance xmlns=\"urn:example:test681\">
         <name>blue</name><active>true</active>
       </instance>
       <user xmlns=\"urn:example:test681\">
         <iref>blue</iref>
       </user>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Setup: commit (expect ok)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# E1: delete the entire instance[blue] entry.
# Without fix: commit succeeds  (MUST silently skipped — BUG)
# With    fix: commit fails     (MUST re-evaluated, instance gone)
# ---------------------------------------------------------------------------
new "E1: delete entire instance[blue]"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <instance xmlns=\"urn:example:test681\"
                 xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"
                 nc:operation=\"delete\">
         <name>blue</name>
       </instance>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "E1: commit after deleting instance[blue] — MUST fail expected"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    stop_backend -f $cfg
fi

endtest
