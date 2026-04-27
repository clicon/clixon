#!/usr/bin/env bash
# Test incremental (transaction-aware) leafref validation optimization.
#
# Verifies that leafref checks are skipped for unchanged subtrees and run
# for changed subtrees, using CLIXON_DBG_VALIDATE log messages as the
# observable signal.
#
# YANG model has several independent sections, each with a leafref that
# covers a different xpath depth pattern:
#
#   sectionA: depth=1 leafref
#             src/ref path: "../targets/group/name"  (one ../ step)
#             common ancestor at depth=1 is sectionA itself
#
#   sectionB: depth=2 leafref
#             in sectionB/entry/ref: "../../targets/group/name" (two ../ steps)
#             common ancestor at depth=2 is sectionB itself
#
#   sectionC: absolute leafref
#             "/t:targets/t:group/t:name"  (absolute path, depth=-1, never skipped)
#
#   targets:  container with a list of groups (leafref targets)
#   trigger:  unrelated leaf used to drive commits without touching A-C
#
# Test sequence:
#   Setup:    populate all sections with valid initial state
#
#   Leafref-A: A1: edit trigger only; sectionA leafref skipped   (skip leafref)
#              A2: delete target group; sectionA ref becomes dangling (check leafref, fail)
#              A3: restore target group; commit OK
#
#   Leafref-B: B1: edit trigger only; sectionB entry/ref skipped (skip leafref)
#              B2: delete target group; sectionB ref becomes dangling (check leafref, fail)
#              B3: restore target group; commit OK
#
#   Leafref-C: C1: edit trigger only; sectionC absolute leafref NOT skipped (check leafref)

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/test.yang
LOGFILE=$dir/backend.log

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

# YANG model covering three leafref xpath depth patterns:
#   targets          container with target list (leafref destinations)
#   sectionA         leaf ref       depth=1  "../targets/group/name"
#   sectionB         list entry/ref depth=2  "../../targets/group/name"
#   sectionC         leaf ref       absolute "/t:targets/t:group/t:name"
#   trigger          no constraints (trigger-only leaf)
cat <<EOF > $fyang
module test {
   yang-version 1.1;
   namespace "urn:example:test";
   prefix t;
   revision 2024-01-01;

   /* Leafref target: a list of named groups */
   container targets {
      list group {
         key name;
         leaf name {
            type string;
         }
      }
   }

   /* sectionA: depth=1 leafref — "../targets/group/name"
    * The path goes up 1 step (ref → sectionA) then down to targets/group/name.
    * Common ancestor at depth=1 is sectionA. */
   container sectionA {
      /* leaf targets is a sibling in sectionA so sectionA is the common ancestor */
      container targets {
         list group {
            key name;
            leaf name {
               type string;
            }
         }
      }
      leaf ref {
         type leafref {
            path "../targets/group/name";
         }
      }
   }

   /* sectionB: depth=2 leafref — "../../targets/group/name"
    * leaf ref is inside sectionB/entry; path goes up 2 steps to sectionB.
    * Common ancestor at depth=2 is sectionB. */
   container sectionB {
      container targets {
         list group {
            key name;
            leaf name {
               type string;
            }
         }
      }
      list entry {
         key name;
         leaf name {
            type string;
         }
         leaf ref {
            type leafref {
               path "../../targets/group/name";
            }
         }
      }
   }

   /* sectionC: absolute leafref — "/t:targets/t:group/t:name"
    * Absolute path; depth=-1; can never be safely skipped. */
   container sectionC {
      leaf ref {
         type leafref {
            path "/t:targets/t:group/t:name";
         }
      }
   }

   /* trigger: no constraints, used to trigger commits without touching A-C */
   container trigger {
      leaf value {
         type string;
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
    new "start backend with validate debug: -s init -f $cfg"
    DBG=validate start_backend -s init -f $cfg -l f$LOGFILE
fi

new "wait backend"
wait_backend

# ===========================================================================
# Setup: populate all sections with valid initial state
# ===========================================================================
new "Setup: populate targets, sectionA, sectionB, sectionC, trigger"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <targets xmlns=\"urn:example:test\">
         <group><name>grp1</name></group>
         <group><name>grp2</name></group>
       </targets>
       <sectionA xmlns=\"urn:example:test\">
         <targets>
           <group><name>grp1</name></group>
           <group><name>grp2</name></group>
         </targets>
         <ref>grp1</ref>
       </sectionA>
       <sectionB xmlns=\"urn:example:test\">
         <targets>
           <group><name>grp1</name></group>
           <group><name>grp2</name></group>
         </targets>
         <entry><name>e1</name><ref>grp1</ref></entry>
       </sectionB>
       <sectionC xmlns=\"urn:example:test\"><ref>grp1</ref></sectionC>
       <trigger xmlns=\"urn:example:test\"><value>init</value></trigger>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Setup: commit initial valid state"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ===========================================================================
# Leafref-A: depth=1  "../targets/group/name" on sectionA/ref
# ===========================================================================

# ---------------------------------------------------------------------------
# A1: edit trigger only -> sectionA/ref leafref should be skipped (unchanged)
# ---------------------------------------------------------------------------
new "Clear log before A1"
sudo truncate -s 0 $LOGFILE

new "A1: edit trigger only (sectionA unchanged)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <trigger xmlns=\"urn:example:test\"><value>A1</value></trigger>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "A1: commit trigger"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "A1: check sectionA/ref leafref skipped (unchanged, depth=1)"
expectpart "$(cat $LOGFILE)" 0 "skip leafref" --not-- "check leafref.*targets/group/name"

# ---------------------------------------------------------------------------
# A2: delete sectionA target group grp1 -> sectionA/ref becomes dangling
# ---------------------------------------------------------------------------
new "Clear log before A2"
sudo truncate -s 0 $LOGFILE

new "A2: delete sectionA/targets/group[name=grp1] (sectionA/ref=grp1 becomes dangling)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <targets>
           <group xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\">
             <name>grp1</name>
           </group>
         </targets>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "A2: commit sectionA target deletion (expect leafref error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard A2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# A3: add a new target group grp3 and update ref -> leafref passes
# ---------------------------------------------------------------------------
new "A3: add sectionA/targets/group=grp3 and set ref=grp3"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <targets>
           <group><name>grp3</name></group>
         </targets>
         <ref>grp3</ref>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "A3: commit sectionA update (expect ok)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Restore sectionA to grp1
new "A3: restore sectionA ref=grp1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <targets>
           <group><name>grp1</name></group>
         </targets>
         <ref>grp1</ref>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "A3: commit restore sectionA"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ===========================================================================
# Leafref-B: depth=2  "../../targets/group/name" on sectionB/entry/ref
# ===========================================================================

# ---------------------------------------------------------------------------
# B1: edit trigger only -> sectionB entry/ref leafref should be skipped
# ---------------------------------------------------------------------------
new "Clear log before B1"
sudo truncate -s 0 $LOGFILE

new "B1: edit trigger only (sectionB unchanged)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <trigger xmlns=\"urn:example:test\"><value>B1</value></trigger>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "B1: commit trigger"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "B1: check sectionB/entry/ref leafref skipped (unchanged, depth=2)"
expectpart "$(cat $LOGFILE)" 0 "skip leafref" --not-- "check leafref.*targets/group/name"

# ---------------------------------------------------------------------------
# B2: delete sectionB target group grp1 -> sectionB/entry/ref becomes dangling
# ---------------------------------------------------------------------------
new "Clear log before B2"
sudo truncate -s 0 $LOGFILE

new "B2: delete sectionB/targets/group[name=grp1] (sectionB/entry/ref=grp1 becomes dangling)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionB xmlns=\"urn:example:test\">
         <targets>
           <group xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\">
             <name>grp1</name>
           </group>
         </targets>
       </sectionB>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "B2: commit sectionB target deletion (expect leafref error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard B2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# B3: add new entry pointing at grp2 -> leafref passes
# ---------------------------------------------------------------------------
new "B3: add sectionB/entry[name=e2] pointing at grp2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionB xmlns=\"urn:example:test\">
         <entry><name>e2</name><ref>grp2</ref></entry>
       </sectionB>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "B3: commit new sectionB entry (expect ok)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ===========================================================================
# Leafref-C: absolute path  "/t:targets/t:group/t:name"
#   Absolute leafref paths have depth=-1 and can never be skipped.
#   When trigger changes, sectionC/ref must still be re-evaluated.
# ===========================================================================

# ---------------------------------------------------------------------------
# C1: edit trigger only -> sectionC/ref absolute leafref NOT skipped
# ---------------------------------------------------------------------------
new "Clear log before C1"
sudo truncate -s 0 $LOGFILE

new "C1: edit trigger only (sectionC absolute leafref)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <trigger xmlns=\"urn:example:test\"><value>C1</value></trigger>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "C1: commit trigger"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "C1: check sectionC/ref absolute leafref was re-evaluated (not skipped)"
# Absolute path leafref is never skipped even when sectionC is unchanged.
expectpart "$(cat $LOGFILE)" 0 "check leafref" --not-- "skip leafref.*t:targets"

# ---------------------------------------------------------------------------
# C2: delete global target group that sectionC/ref points to -> leafref fails
# ---------------------------------------------------------------------------
new "Clear log before C2"
sudo truncate -s 0 $LOGFILE

new "C2: delete targets/group[name=grp1] (sectionC/ref=grp1 becomes dangling)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <targets xmlns=\"urn:example:test\">
         <group xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\">
           <name>grp1</name>
         </group>
       </targets>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "C2: commit target deletion (expect leafref error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard C2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    stop_backend -f $cfg
fi

endtest
