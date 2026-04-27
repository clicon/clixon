#!/usr/bin/env bash
# Test incremental (transaction-aware) MUST expression validation optimization.
#
# Verifies that MUST checks are skipped for unchanged subtrees and run
# for changed subtrees, using CLIXON_DBG_VALIDATE log messages as the
# observable signal.
#
# YANG model has several independent sections, each with a MUST expression
# that covers a different xpath pattern:
#
#   sectionA: local-only must (depth=0)
#             leaf x must: "not(. = 'bad')"  (self only)
#
#   sectionB: sibling must (depth=1, relative)
#             leaf enable must: "../mode = 'active' or not(. = 'true')"
#             (one parent step to reach sibling mode)
#
#   sectionC: deep relative must (depth=2)
#             list entry / leaf ref must:
#             "../../allowed = 'yes'"
#             (two parent steps: ref→entry→sectionC, controlling leaf is
#              a sibling of the list within sectionC itself)
#
#   sectionD: absolute path must
#             leaf token must:
#             "count(/t:root/t:global/t:token[. = current()]) > 0"
#             (absolute path — cannot be safely skipped)
#
#   sectionE: unrelated leaf used to trigger commits without touching A-D
#
# Test sequence:
#   Setup:    populate all sections so running is fully valid
#
#   Must-A:  A1: edit sectionE only; sectionA must is skipped  (skip must)
#            A2: change sectionA/x to 'bad'; commit fails       (check must, fail)
#            A3: change sectionA/x to valid; commit OK          (check must, pass)
#
#   Must-B:  B1: edit sectionE only; sectionB must is skipped  (skip must)
#            B2: change sectionB/enable='true' with mode='inactive';
#                commit fails                                   (check must, fail)
#            B3: restore sectionB; commit OK
#
#   Must-C:  C1: edit sectionE only; sectionC must is skipped  (skip must)
#            C2: change sectionC/allowed=no; commit fails        (check must, fail)
#            C3: restore; commit OK
#
#   Must-D:  D1: edit sectionE only; sectionD absolute must
#                is re-evaluated (cannot skip — absolute path) (check must)
#            D2: set token that is not in global token list;
#                commit fails                                   (check must, fail)
#            D3: restore; commit OK

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

# YANG model covering four MUST xpath patterns:
#   sectionA  leaf x           must: self only (depth=0)
#   sectionB  leaf enable      must: sibling ref (depth=1)
#   sectionC  list entry/ref   must: ancestor ref (depth=2)
#   sectionD  leaf token       must: absolute path
#   sectionE  leaf value       no constraints (trigger-only)
#   root/global                shared data referenced by sectionD absolute must
cat <<EOF > $fyang
module test {
   yang-version 1.1;
   namespace "urn:example:test";
   prefix t;
   revision 2024-01-01;

   /* Global data referenced by sectionD absolute must */
   container root {
      container global {
         leaf-list token {
            type string;
         }
      }
   }

   /* sectionA: local must — references only self (depth=0) */
   container sectionA {
      leaf x {
         type string;
         must "not(. = 'bad')" {
            error-message "x must not be 'bad'";
         }
      }
   }

   /* sectionB: sibling must — references sibling leaf mode (depth=1) */
   container sectionB {
      leaf mode {
         type string;
      }
      leaf enable {
         type string;
         must "../mode = 'active' or not(. = 'true')" {
            error-message "enable=true requires mode=active";
         }
      }
   }

   /* sectionC: ancestor must — references ../../allowed (depth=2)
    * path from ref: ref -> entry (1) -> sectionC (2) -> leaf allowed
    * sectionC contains both the controlling leaf and the list, so when
    * only sectionE changes, sectionC has no XML_FLAG_CHANGE -> skip fires */
   container sectionC {
      leaf allowed {
         type string;
      }
      list entry {
         key name;
         leaf name {
            type string;
         }
         leaf ref {
            type string;
            must "../../allowed = 'yes'" {
               error-message "ref requires sectionC/allowed=yes";
            }
         }
      }
   }

   /* sectionD: absolute must — references /t:root/t:global/t:token */
   container sectionD {
      leaf token {
         type string;
         must "count(/t:root/t:global/t:token[. = current()]) > 0" {
            error-message "token must exist in global token list";
         }
      }
   }

   /* sectionE: no constraints, used to trigger commits without touching A-D */
   container sectionE {
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
# Setup: populate all sections with valid data so running is fully valid
# ===========================================================================
new "Setup: populate global, sectionA, sectionB, sectionC, sectionD, sectionE"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <root xmlns=\"urn:example:test\">
         <global>
           <token>tok1</token>
           <token>tok2</token>
         </global>
       </root>
       <sectionA xmlns=\"urn:example:test\"><x>good</x></sectionA>
       <sectionB xmlns=\"urn:example:test\"><mode>active</mode><enable>true</enable></sectionB>
       <sectionC xmlns=\"urn:example:test\">
         <allowed>yes</allowed>
         <entry><name>e1</name><ref>someref</ref></entry>
       </sectionC>
       <sectionD xmlns=\"urn:example:test\"><token>tok1</token></sectionD>
       <sectionE xmlns=\"urn:example:test\"><value>init</value></sectionE>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Setup: commit initial valid state"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ===========================================================================
# Must-A: self-only must (depth=0)  "not(. = 'bad')" on sectionA/x
# ===========================================================================

# ---------------------------------------------------------------------------
# A1: edit sectionE only -> sectionA/x must should be skipped (unchanged)
# ---------------------------------------------------------------------------
new "Clear log before A1"
sudo truncate -s 0 $LOGFILE

new "A1: edit sectionE only (sectionA unchanged)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionE xmlns=\"urn:example:test\"><value>A1</value></sectionE>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "A1: commit sectionE"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "A1: check sectionA/x must skipped (unchanged, depth=0)"
expectpart "$(cat $LOGFILE)" 0 "skip must.*not.*bad" --not-- "check must.*not.*bad"

# ---------------------------------------------------------------------------
# A2: set sectionA/x='bad' -> must fails, commit rejected
# ---------------------------------------------------------------------------
new "Clear log before A2"
sudo truncate -s 0 $LOGFILE

new "A2: set sectionA/x to 'bad' (must violation)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\"><x>bad</x></sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "A2: commit sectionA/x='bad' (expect must error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard A2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# A3: set sectionA/x='good2' -> must passes, commit OK
# ---------------------------------------------------------------------------
new "A3: set sectionA/x to valid value"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionA xmlns=\"urn:example:test\"><x>good2</x></sectionA>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "A3: commit sectionA/x=good2 (expect ok)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ===========================================================================
# Must-B: sibling must (depth=1)  "../mode = 'active' or not(. = 'true')"
# ===========================================================================

# ---------------------------------------------------------------------------
# B1: edit sectionE only -> sectionB must should be skipped (unchanged)
# ---------------------------------------------------------------------------
new "Clear log before B1"
sudo truncate -s 0 $LOGFILE

new "B1: edit sectionE only (sectionB unchanged)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionE xmlns=\"urn:example:test\"><value>B1</value></sectionE>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "B1: commit sectionE"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "B1: check sectionB/enable must skipped (unchanged, depth=1)"
expectpart "$(cat $LOGFILE)" 0 "skip must.*mode.*active" --not-- "check must.*mode.*active"

# ---------------------------------------------------------------------------
# B2: change sectionB/mode='inactive', leave enable='true' -> must fails
# ---------------------------------------------------------------------------
new "Clear log before B2"
sudo truncate -s 0 $LOGFILE

new "B2: set sectionB/mode=inactive (enable=true violates must)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionB xmlns=\"urn:example:test\"><mode>inactive</mode></sectionB>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "B2: commit sectionB/mode=inactive (expect must error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard B2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# B3: set enable='false', mode='inactive' -> must passes (enable not 'true')
# ---------------------------------------------------------------------------
new "B3: set sectionB enable=false mode=inactive (must passes)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionB xmlns=\"urn:example:test\"><mode>inactive</mode><enable>false</enable></sectionB>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "B3: commit (expect ok)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Restore sectionB to active/true
new "B3: restore sectionB mode=active enable=true"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionB xmlns=\"urn:example:test\"><mode>active</mode><enable>true</enable></sectionB>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "B3: commit restore"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ===========================================================================
# Must-C: ancestor must (depth=2)  "../../allowed = 'yes'"
#   on sectionC/entry/ref
# Note: the path goes up 2 levels (ref → entry → sectionC), then accesses
# the sibling leaf 'allowed' inside sectionC.  The ancestor at depth=2 is
# sectionC itself; if only sectionE changes, sectionC has no CHANGE → skip.
# ===========================================================================

# ---------------------------------------------------------------------------
# C1: edit sectionE only -> sectionC entry/ref must should be skipped
# ---------------------------------------------------------------------------
new "Clear log before C1"
sudo truncate -s 0 $LOGFILE

new "C1: edit sectionE only (sectionC unchanged)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionE xmlns=\"urn:example:test\"><value>C1</value></sectionE>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "C1: commit sectionE"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "C1: check sectionC/entry/ref must skipped (unchanged, depth=2)"
expectpart "$(cat $LOGFILE)" 0 "skip must.*allowed" --not-- "check must.*allowed"

# ---------------------------------------------------------------------------
# C2: set sectionC/allowed='no' -> sectionC/entry/ref must fails
# ---------------------------------------------------------------------------
new "Clear log before C2"
sudo truncate -s 0 $LOGFILE

new "C2: set sectionC/allowed=no (sectionC/entry/ref must will fail)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionC xmlns=\"urn:example:test\">
         <allowed>no</allowed>
       </sectionC>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "C2: commit sectionC/allowed=no (expect must error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard C2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# C3: add new sectionC entry while sectionC/allowed='yes' -> must passes
# ---------------------------------------------------------------------------
new "C3: add sectionC/entry[name=e2] (sectionC/allowed=yes, must passes)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionC xmlns=\"urn:example:test\">
         <entry><name>e2</name><ref>ref2</ref></entry>
       </sectionC>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "C3: commit new sectionC entry (expect ok)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ===========================================================================
# Must-D: absolute must (depth=∞)
#   "count(/t:root/t:global/t:token[. = current()]) > 0"
#   on sectionD/token
#   Absolute paths cannot be safely skipped using ancestor flags alone.
# ===========================================================================

# ---------------------------------------------------------------------------
# D1: edit sectionE only -> sectionD/token must re-evaluated (absolute path)
# ---------------------------------------------------------------------------
new "Clear log before D1"
sudo truncate -s 0 $LOGFILE

new "D1: edit sectionE only (sectionD unchanged but absolute must)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionE xmlns=\"urn:example:test\"><value>D1</value></sectionE>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "D1: commit sectionE"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "D1: check sectionD/token absolute must was re-evaluated (not skipped)"
# Absolute path must is never skipped, even when sectionD is unchanged.
expectpart "$(cat $LOGFILE)" 0 "check must" --not-- "skip must.*count"

# ---------------------------------------------------------------------------
# D2: set sectionD/token='tok_unknown' -> must fails (not in global token list)
# ---------------------------------------------------------------------------
new "Clear log before D2"
sudo truncate -s 0 $LOGFILE

new "D2: set sectionD/token=tok_unknown (not in global list)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionD xmlns=\"urn:example:test\"><token>tok_unknown</token></sectionD>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "D2: commit sectionD/token=tok_unknown (expect must error)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard D2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# D3: remove sectionD/token from global list -> absolute must fails
#     even though sectionD/token itself is unchanged
#     This is the key test: optimization must NOT skip the absolute must
# ---------------------------------------------------------------------------
new "D3: remove tok1 from global token list (sectionD/token=tok1 must fail)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <root xmlns=\"urn:example:test\">
         <global>
           <token xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\" nc:operation=\"delete\">tok1</token>
         </global>
       </root>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "D3: commit token deletion (expect must error on sectionD/token=tok1)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "<rpc-error>" "" \
  --not-- "<ok/>"

new "discard D3"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><discard-changes/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# D4: add a new token to global list -> sectionD/token still valid
# ---------------------------------------------------------------------------
new "D4: add tok3 to global token list; sectionD/token=tok1 still valid"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <root xmlns=\"urn:example:test\">
         <global><token>tok3</token></global>
       </root>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "D4: commit new token (expect ok)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    stop_backend -f $cfg
fi

endtest
