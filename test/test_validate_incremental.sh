#!/usr/bin/env bash
# Test incremental (transaction-aware) validation optimization.
# Note this is only for running/candidate editing, not between successive edits in candidate
#
# Verifies that mandatory and minmax checks are skipped for unchanged subtrees and
# run for changed subtrees, using CLIXON_DBG_VALIDATE log messages as
# the observable signal.
#
# YANG model has three independent containers:
#   - sectionA: a list with a mandatory leaf (required)
#   - sectionB: a simple leaf (no constraints)
#   - sectionC: a list with max-elements 2
#
# Test sequence (mandatory):
#   1. Add an entry to sectionA (with required mandatory leaf) -> commit OK
#   2. Edit sectionB only -> commit; check that sectionA entry is NOT
#      re-validated (skip mandatory log for it)
#   3. Add a second entry to sectionA (with mandatory leaf) -> commit OK;
#      check that only the new entry is validated, not the first entry
#   4. Negative: try to add an entry missing the mandatory leaf -> commit fails
#
# Test sequence (minmax):
#   Setup: set sectionC/dummy to ensure mid-loop Y_LIST→Y_LEAF switch fires
#   A. Add item c1 to sectionC -> minmax checked, OK
#   B. Edit sectionB only -> sectionC minmax skipped (c1 unchanged)
#   C. Add item c2 to sectionC -> minmax checked, OK (at limit)
#   D. Add item c3 to sectionC (exceeds max) -> minmax checked, commit fails
#   E. Delete item c1 from sectionC -> minmax checked (DEL_ANC), OK

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

cat <<EOF > $fyang
module test {
   yang-version 1.1;
   namespace "urn:example:test";
   prefix t;
   revision 2024-01-01;

   /* sectionA: list with a mandatory leaf */
   container sectionA {
      list entry {
         key name;
         leaf name {
            type string;
         }
         leaf required {
            mandatory true;
            type string;
         }
         leaf optional {
            type string;
         }
      }
   }

   /* sectionB: unrelated simple leaf */
   container sectionB {
      leaf value {
         type string;
      }
   }

   /* sectionC: list with max-elements constraint, for minmax optimization tests.
    * A dummy leaf is added after the list so that xml_yang_validate_minmax
    * triggers the mid-loop Y_LIST→Y_LEAF switch and calls check_minmax on
    * the item list.  The leaf is set once during test setup and stays in
    * running/candidate throughout the minmax tests. */
   container sectionC {
      list item {
         max-elements 2;
         key name;
         leaf name {
            type string;
         }
         leaf value {
            type string;
         }
      }
      leaf dummy {
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
    # Start with validate debug logging to file; DBG=validate enables CLIXON_DBG_VALIDATE
    DBG=validate start_backend -s init -f $cfg -l f$LOGFILE
fi

new "wait backend"
wait_backend

# ---------------------------------------------------------------------------
# Test 1: Add sectionA entry with mandatory leaf -> commit OK
# ---------------------------------------------------------------------------
new "Add sectionA/entry[name=e1] with required leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <entry><name>e1</name><required>val1</required></entry>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit sectionA entry e1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# Test 2: Edit only sectionB -> commit; sectionA entry must NOT be re-validated
# Clear the log first so we can inspect just this commit's output
# ---------------------------------------------------------------------------
new "Clear backend log before sectionB edit"
sudo truncate -s 0 $LOGFILE

new "Edit sectionB/value (sectionA unchanged)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionB xmlns=\"urn:example:test\">
         <value>hello</value>
       </sectionB>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit sectionB edit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check: sectionA/entry[e1] mandatory was skipped (unchanged)"
# The debug log must contain "skip mandatory" and must NOT contain "check mandatory" for entry
expectpart "$(grep 'mandatory.*entry' $LOGFILE)" 0 "skip mandatory" --not-- "check mandatory"

new "Check: sectionB was validated (changed)"
expectpart "$(grep 'check mandatory.*sectionB' $LOGFILE)" 0 "sectionB"

# ---------------------------------------------------------------------------
# Test 3: Add a second entry to sectionA -> only new entry validated
# ---------------------------------------------------------------------------
new "Clear backend log before second sectionA add"
sudo truncate -s 0 $LOGFILE

new "Add sectionA/entry[name=e2] with required leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <entry><name>e2</name><required>val2</required></entry>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit second sectionA entry e2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check: sectionA/entry[e1] mandatory skipped (unchanged)"
expectpart "$(grep 'skip mandatory.*entry' $LOGFILE)" 0 "entry"

new "Check: sectionA/entry[e2] mandatory was checked (new)"
expectpart "$(grep 'check mandatory.*entry' $LOGFILE)" 0 "entry"

# ---------------------------------------------------------------------------
# Test 4: Negative — add entry missing mandatory leaf -> commit must fail
# ---------------------------------------------------------------------------
new "Add sectionA/entry[name=e3] WITHOUT required leaf (negative)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <entry><name>e3</name></entry>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit missing mandatory leaf (expect error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

# Discard the invalid candidate so following tests start clean
new "discard-changes after negative commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# Test 5: Validate (not commit) positive — edit sectionB, validate should pass
# The unchanged sectionA entries must be skipped in validate as well.
# ---------------------------------------------------------------------------
new "Clear backend log before validate test"
sudo truncate -s 0 $LOGFILE

new "Edit sectionB for validate test"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionB xmlns=\"urn:example:test\">
         <value>world</value>
       </sectionB>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate candidate (sectionA unchanged) - expect ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" \
  --not-- "<rpc-error>"

new "Check: sectionA entries skipped during validate (unchanged)"
expectpart "$(sudo grep 'skip mandatory.*entry' $LOGFILE)" 0 "entry"

new "discard-changes after validate test"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# Test 6: Validate (not commit) negative — add entry missing mandatory leaf
# ---------------------------------------------------------------------------
new "Add sectionA/entry[name=e4] WITHOUT required leaf (validate negative)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <entry><name>e4</name></entry>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate candidate missing mandatory leaf (expect error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard-changes after negative validate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# Test 7: Delete mandatory leaf from an existing entry -> commit must fail
# This tests the deletion path: the target entry has no XML_FLAG_CHANGE because
# deletion flags are only set on the source tree. The vtd_has_dels guard in
# the optimization must prevent the mandatory check from being skipped.
# ---------------------------------------------------------------------------
new "Delete required leaf from entry e1 (commit negative)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <entry>
           <name>e1</name>
           <required xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\"/>
         </entry>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit deletion of mandatory leaf (expect error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard-changes after deletion of mandatory leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# Test 8: Delete mandatory leaf from entry -> validate must also fail
# ---------------------------------------------------------------------------
new "Delete required leaf from entry e1 (validate negative)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <entry>
           <name>e1</name>
           <required xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\"/>
         </entry>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate candidate with deleted mandatory leaf (expect error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard-changes after negative validate on deletion"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# Test 7: Delete mandatory leaf from existing entry (running -> candidate)
#
# This is the critical case: running has entry[e1]/required=val1.
# Candidate deletes the required leaf from entry[e1].
# The target entry[e1] has no XML_FLAG_CHANGE set (deletions only mark
# the SOURCE tree). Without vtd_has_dels guard, our optimization would
# incorrectly skip mandatory check on target entry[e1].
# ---------------------------------------------------------------------------

new "Delete mandatory required leaf from entry[e1] in candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <entry>
           <name>e1</name>
           <required xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\">val1</required>
         </entry>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit delete of mandatory leaf (expect error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard-changes after delete mandatory test"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate candidate after deleting mandatory leaf (expect error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\">
         <entry>
           <name>e1</name>
           <required xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\">val1</required>
         </entry>
       </sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard-changes after validate delete mandatory test"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# Minmax optimization tests (sectionC: list with max-elements 2)
# sectionC also has a leaf "dummy" that follows the list in the XML tree.
# Setup: initialise sectionC/dummy so it is present in running throughout
# ---------------------------------------------------------------------------
new "Setup: set sectionC/dummy to anchor minmax mid-loop check"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionC xmlns=\"urn:example:test\">
         <dummy>setup</dummy>
       </sectionC>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Setup: commit sectionC/dummy"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# Test A: Add first item to sectionC — minmax must be CHECKED
# ---------------------------------------------------------------------------
new "Clear log before minmax test A (add c1)"
sudo truncate -s 0 $LOGFILE

new "Add sectionC/item[name=c1]"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionC xmlns=\"urn:example:test\">
         <item><name>c1</name><value>v1</value></item>
       </sectionC>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit add c1 (minmax checked, 1 <= 2, OK)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check: sectionC minmax checked after add c1"
expectpart "$(grep 'minmax.*sectionC' $LOGFILE)" 0 "check minmax" --not-- "skip minmax"

# ---------------------------------------------------------------------------
# Test B: Edit sectionB only — sectionC minmax must be SKIPPED (c1 unchanged)
# ---------------------------------------------------------------------------
new "Clear log before minmax test B (sectionB-only edit)"
sudo truncate -s 0 $LOGFILE

new "Edit sectionB (sectionC unchanged)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionB xmlns=\"urn:example:test\">
         <value>minmax-test</value>
       </sectionB>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit sectionB edit (sectionC minmax should be skipped)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check: sectionC minmax skipped (sectionB-only change)"
expectpart "$(grep 'minmax.*sectionC' $LOGFILE)" 0 "skip minmax" --not-- "check minmax"

# ---------------------------------------------------------------------------
# Test C: Add second item to sectionC — minmax checked, at limit (2 == 2)
# ---------------------------------------------------------------------------
new "Clear log before minmax test C (add c2)"
sudo truncate -s 0 $LOGFILE

new "Add sectionC/item[name=c2]"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionC xmlns=\"urn:example:test\">
         <item><name>c2</name><value>v2</value></item>
       </sectionC>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit add c2 (minmax checked, 2 == 2, at limit OK)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check: sectionC minmax checked after add c2"
expectpart "$(grep 'minmax.*sectionC' $LOGFILE)" 0 "check minmax" --not-- "skip minmax"

# ---------------------------------------------------------------------------
# Test D: Add third item (exceeds max-elements 2) — minmax checked, commit fails
# ---------------------------------------------------------------------------
new "Clear log before minmax test D (add c3, negative)"
sudo truncate -s 0 $LOGFILE

new "Add sectionC/item[name=c3] (would exceed max-elements 2)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionC xmlns=\"urn:example:test\">
         <item><name>c3</name><value>v3</value></item>
       </sectionC>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit add c3 (minmax checked, 3 > 2, expect error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "Check: sectionC minmax checked (negative add)"
expectpart "$(grep 'minmax.*sectionC' $LOGFILE)" 0 "check minmax" --not-- "skip minmax"

new "discard-changes after negative minmax commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# Test E: Delete item c1 from sectionC — minmax must be CHECKED (DEL_ANC path)
# A deletion only marks the SOURCE tree; XML_FLAG_DEL_ANC is propagated into
# the TARGET sectionC container by find_target_equiv() so the skip is blocked.
# ---------------------------------------------------------------------------
new "Clear log before minmax test E (delete c1)"
sudo truncate -s 0 $LOGFILE

new "Delete sectionC/item[name=c1]"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionC xmlns=\"urn:example:test\">
         <item xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\">
           <name>c1</name>
         </item>
       </sectionC>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit delete c1 (minmax checked via DEL_ANC, 1 <= 2, OK)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check: sectionC minmax checked after delete (DEL_ANC propagation)"
expectpart "$(grep 'minmax.*sectionC' $LOGFILE)" 0 "check minmax" --not-- "skip minmax"

if [ $BE -ne 0 ]; then
    new "kill backend"
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
