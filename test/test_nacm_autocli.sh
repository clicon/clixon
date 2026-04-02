#!/usr/bin/env bash
# Test NACM-aware autocli: verify CLI tab completion hides YANG nodes that are
# denied by NACM rules for the current user.
#
# NACM filtering is applied server-side in AUTOCLI_CACHE_READ mode.
# The backend generates per-user clispec (bypassing file cache) when NACM rules apply.
#
# Tests:
#  1. read-default=permit + explicit deny on /secret -> node hidden from set ?
#  2. read-default=deny (various permit paths) - complex YANG with lists/leaves:
#     2a. permit /visible only -> only visible shown, devices/mgmt hidden
#     2b. permit /visible + /devices/device/address -> devices/device/address shown,
#         description and settings hidden (path mismatch)
#     2c. permit /devices/device -> all list children visible (descendant logic)
#     2d. admin (permit-all, no path) -> sees everything
#  3. NACM disabled -> all nodes visible
#  4. grouping/uses + grouping-treeref=true: deny a leaf inside a grouping-based container
#  5. CLI edit mode: NACM filtering uses full @basemodel path, not working-point-relative path
#  6. permit-default + deny /devices/device/settings (leaf inside list): settings hidden, address/desc visible
#  7. deny-default + permit /devices/device/settings/enabled (deeply nested): ancestor chain visible,
#     sibling leaves hidden, correct leaf visible inside nested container
#  8. CLICON_NACM_AUTOCLI=false: filtering disabled; denied nodes visible in CLI despite NACM deny rule

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf.xml
cfd=$dir/conf.d
if [ ! -d $cfd ]; then
    mkdir $cfd
fi
fyang=$dir/example.yang
clidir=$dir/cli

if [ -d $clidir ]; then
    rm -rf $clidir/*
else
    mkdir $clidir
fi

cachedir=$dir/autocli-cache
if [ ! -d $cachedir ]; then
    mkdir $cachedir
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_CONFIGDIR>$cfd</CLICON_CONFIGDIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_AUTOCLI_CACHE_DIR>$cachedir</CLICON_AUTOCLI_CACHE_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_NACM_CREDENTIALS>none</CLICON_NACM_CREDENTIALS>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
  <CLICON_NACM_AUTOCLI>true</CLICON_NACM_AUTOCLI>
</clixon-config>
EOF

cat <<EOF > $cfd/autocli.xml
<clixon-config xmlns="http://clicon.org/config">
   <autocli>
      <module-default>false</module-default>
      <list-keyword-default>kw-nokey</list-keyword-default>
      <grouping-treeref>true</grouping-treeref>
      <treeref-state-default>false</treeref-state-default>
      <rule>
         <name>include example</name>
         <operation>enable</operation>
         <module-name>example*</module-name>
      </rule>
      <clispec-cache>read</clispec-cache>
   </autocli>
</clixon-config>
EOF

# YANG module with containers, a list, and nested structure
cat <<EOF > $fyang
module example {
  namespace "urn:example:clixon";
  prefix ex;
  container public {
    description "Publicly accessible config";
    leaf value {
      type string;
    }
  }
  container secret {
    description "Restricted config";
    leaf token {
      type string;
    }
  }
  container visible {
    description "Visible to limited user";
    leaf data {
      type string;
    }
    leaf extra {
      type string;
    }
  }
  container devices {
    description "Device inventory";
    list device {
      key name;
      leaf name {
        type string;
      }
      leaf address {
        type string;
      }
      leaf description {
        type string;
      }
      container settings {
        leaf enabled {
          type boolean;
        }
        leaf priority {
          type uint8;
        }
      }
    }
  }
  container mgmt {
    description "Management config";
    leaf admin-password {
      type string;
    }
    leaf log-level {
      type string;
    }
  }
  grouping grp-common {
    description "Reusable common leaves";
    leaf status {
      type string;
    }
    leaf owner {
      type string;
    }
  }
  container grouped {
    description "Container using grouping";
    uses grp-common;
    leaf extra-grouped {
      type string;
    }
  }
  container also-grouped {
    description "Another container reusing the same grouping";
    uses grp-common;
  }
}
EOF

# CLI spec
cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
edit @datamodelmode, cli_auto_edit("basemodel");
up, cli_auto_up("basemodel");
top, cli_auto_top("basemodel");
set @datamodel, cli_auto_set();
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "text", true, false);
}
EOF

# NACM config for Test 1: read-default=permit, deny /secret for limited user
NACM_DENY_SECRET="<nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\"><enable-nacm>true</enable-nacm><read-default>permit</read-default><write-default>deny</write-default><exec-default>permit</exec-default>${NGROUPS}${NADMIN}<rule-list><name>limited-acl</name><group>limited</group><rule><name>deny-secret</name><module-name>example</module-name><path xmlns:ex=\"urn:example:clixon\">/ex:secret</path><access-operations>read</access-operations><action>deny</action></rule></rule-list></nacm>"

# NACM config for Test 2a: read-default=deny, only /visible permitted
NACM_PERMIT_VISIBLE="<nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\"><enable-nacm>true</enable-nacm><read-default>deny</read-default><write-default>deny</write-default><exec-default>permit</exec-default>${NGROUPS}${NADMIN}<rule-list><name>limited-acl</name><group>limited</group><rule><name>permit-visible</name><module-name>example</module-name><path xmlns:ex=\"urn:example:clixon\">/ex:visible</path><access-operations>read</access-operations><action>permit</action></rule></rule-list></nacm>"

# NACM config for Test 2b: read-default=deny, permit /visible and /devices/device/address
NACM_PERMIT_ADDRESS="<nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\"><enable-nacm>true</enable-nacm><read-default>deny</read-default><write-default>deny</write-default><exec-default>permit</exec-default>${NGROUPS}${NADMIN}<rule-list><name>limited-acl</name><group>limited</group><rule><name>permit-visible</name><module-name>example</module-name><path xmlns:ex=\"urn:example:clixon\">/ex:visible</path><access-operations>read</access-operations><action>permit</action></rule><rule><name>permit-address</name><module-name>example</module-name><path xmlns:ex=\"urn:example:clixon\">/ex:devices/ex:device/ex:address</path><access-operations>read</access-operations><action>permit</action></rule></rule-list></nacm>"

# NACM config for Test 2c: read-default=deny, permit /devices/device (whole list subtree)
NACM_PERMIT_DEVICE="<nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\"><enable-nacm>true</enable-nacm><read-default>deny</read-default><write-default>deny</write-default><exec-default>permit</exec-default>${NGROUPS}${NADMIN}<rule-list><name>limited-acl</name><group>limited</group><rule><name>permit-device</name><module-name>example</module-name><path xmlns:ex=\"urn:example:clixon\">/ex:devices/ex:device</path><access-operations>read</access-operations><action>permit</action></rule></rule-list></nacm>"

# NACM config for Test 3: NACM disabled
NACM_DISABLED='<nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm"><enable-nacm>false</enable-nacm><read-default>permit</read-default><write-default>deny</write-default><exec-default>permit</exec-default></nacm>'

# NACM config for Test 4: read-default=permit, deny /grouped/status for limited user
# Tests that NACM filtering works through grouping treeref (grouping-treeref=true)
NACM_DENY_GROUPED_STATUS="<nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\"><enable-nacm>true</enable-nacm><read-default>permit</read-default><write-default>deny</write-default><exec-default>permit</exec-default>${NGROUPS}${NADMIN}<rule-list><name>limited-acl</name><group>limited</group><rule><name>deny-grouped-status</name><module-name>example</module-name><path xmlns:ex=\"urn:example:clixon\">/ex:grouped/ex:status</path><access-operations>read</access-operations><action>deny</action></rule></rule-list></nacm>"

# NACM config for Test 5: read-default=deny, permit /visible + /devices/device/address
# Reuses NACM_PERMIT_ADDRESS but tests it from edit mode
# (no new NACM config needed — tests with existing rules)

# NACM config for Test 6: read-default=permit, deny /devices/device/settings (leaf inside list)
NACM_DENY_DEVICE_SETTINGS="<nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\"><enable-nacm>true</enable-nacm><read-default>permit</read-default><write-default>deny</write-default><exec-default>permit</exec-default>${NGROUPS}${NADMIN}<rule-list><name>limited-acl</name><group>limited</group><rule><name>deny-device-settings</name><module-name>example</module-name><path xmlns:ex=\"urn:example:clixon\">/ex:devices/ex:device/ex:settings</path><access-operations>read</access-operations><action>deny</action></rule></rule-list></nacm>"

# NACM config for Test 7: read-default=deny, permit only /devices/device/settings/enabled
NACM_PERMIT_SETTINGS_ENABLED="<nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\"><enable-nacm>true</enable-nacm><read-default>deny</read-default><write-default>deny</write-default><exec-default>permit</exec-default>${NGROUPS}${NADMIN}<rule-list><name>limited-acl</name><group>limited</group><rule><name>permit-settings-enabled</name><module-name>example</module-name><path xmlns:ex=\"urn:example:clixon\">/ex:devices/ex:device/ex:settings/ex:enabled</path><access-operations>read</access-operations><action>permit</action></rule></rule-list></nacm>"

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

# --- Test 1: read-default=permit, explicit deny on /secret ---
new "Test 1: Load NACM with read-default=permit, deny /secret for limited user"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_DENY_SECRET</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 1 commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 1a: wilma (limited) - 'set ?' shows public/visible/devices/mgmt, NOT secret"
expectpart "$(echo "set ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "public" "visible" "devices" "mgmt" --not-- "secret"

new "Test 1b: admin - 'set ?' shows all nodes including secret"
expectpart "$(echo "set ?" | $clixon_cli -f $cfg -U admin 2>&1)" 0 "public" "visible" "devices" "mgmt" "secret"

# --- Test 2a: read-default=deny, only /visible permitted ---
new "Test 2a: Load NACM with read-default=deny, permit only /visible"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_PERMIT_VISIBLE</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 2a commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 2a: wilma - 'set ?' shows only visible, NOT public/secret/devices/mgmt"
expectpart "$(echo "set ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "visible" --not-- "public" --not-- "secret" --not-- "devices" --not-- "mgmt"

new "Test 2a: wilma - 'set visible ?' shows descendant leaves data and extra"
expectpart "$(echo "set visible ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "data" "extra"

new "Test 2a: admin - 'set ?' shows all nodes (permit-all rule, no path)"
expectpart "$(echo "set ?" | $clixon_cli -f $cfg -U admin 2>&1)" 0 "public" "visible" "devices" "mgmt" "secret"

# --- Test 2b: read-default=deny, permit /visible + /devices/device/address ---
new "Test 2b: Load NACM with read-default=deny, permit /visible and /devices/device/address"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_PERMIT_ADDRESS</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 2b commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 2b: wilma - 'set ?' shows visible and devices (ancestor), NOT public/secret/mgmt"
expectpart "$(echo "set ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "visible" "devices" --not-- "public" --not-- "secret" --not-- "mgmt"

new "Test 2b: wilma - 'set devices device x ?' shows address, NOT description or settings"
expectpart "$(echo "set devices device x ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "address" --not-- "description" --not-- "settings"

new "Test 2b: wilma - 'set visible ?' shows data and extra (full visible subtree)"
expectpart "$(echo "set visible ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "data" "extra"

# --- Test 2c: read-default=deny, permit /devices/device (whole list subtree) ---
new "Test 2c: Load NACM with read-default=deny, permit /devices/device"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_PERMIT_DEVICE</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 2c commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 2c: wilma - 'set ?' shows devices (ancestor), NOT visible/public/secret/mgmt"
expectpart "$(echo "set ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "devices" --not-- "visible" --not-- "public" --not-- "secret" --not-- "mgmt"

new "Test 2c: wilma - 'set devices device x ?' shows address/description/settings (full subtree)"
expectpart "$(echo "set devices device x ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "address" "description" "settings"

new "Test 2c: wilma - 'set devices device x settings ?' shows enabled and priority"
expectpart "$(echo "set devices device x settings ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "enabled" "priority"

# --- Test 3: NACM disabled -> all nodes visible ---
new "Test 3: Load NACM with enable-nacm=false"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_DISABLED</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 3: Commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 3: NACM disabled - all nodes visible for any user"
expectpart "$(echo "set ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "public" "visible" "devices" "mgmt" "secret"

# --- Test 4: grouping/uses with grouping-treeref=true ---
# Verifies that NACM filtering works correctly when the CLI is generated using
# treeref (indirect references) for YANG groupings.  With grouping-treeref=true
# 'grouped' and 'also-grouped' share the same @treeref for grp-common; the
# NACM callback must still resolve the per-container path correctly.
new "Test 4: Load NACM read-default=permit, deny /grouped/status"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_DENY_GROUPED_STATUS</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 4 commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 4a: wilma - 'set ?' shows grouped and also-grouped (ancestor visible)"
expectpart "$(echo "set ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "grouped" "also-grouped"

new "Test 4b: wilma - 'set grouped ?' shows owner and extra-grouped, NOT status (denied)"
expectpart "$(echo "set grouped ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "owner" "extra-grouped" --not-- "status"

new "Test 4c: wilma - 'set also-grouped ?' shows both status and owner (deny only covers /grouped/status)"
expectpart "$(echo "set also-grouped ?" | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "status" "owner"

new "Test 4d: admin - 'set grouped ?' shows all leaves including status"
expectpart "$(echo "set grouped ?" | $clixon_cli -f $cfg -U admin 2>&1)" 0 "status" "owner" "extra-grouped"

# --- Test 5: CLI edit mode ---
# Verifies that NACM filtering works correctly when the user has entered an edit
# context.  The path must be built from the full @basemodel root, not relative to
# the current working point, so filtering decisions are correct regardless of
# how deep the edit has descended.
new "Test 5: Load NACM read-default=permit, deny /secret (edit mode test)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_DENY_SECRET</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 5 commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 5a: wilma - edit into visible; 'set ?' shows data/extra (visible subtree fully permitted)"
expectpart "$(printf 'edit visible\nset ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "data" "extra"

new "Test 5b: wilma - edit into devices device x; 'set ?' shows address/description/settings (no deny)"
expectpart "$(printf 'edit devices\nedit device x\nset ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "address" "description" "settings"

new "Test 5: Load NACM read-default=deny, permit /visible + /devices/device/address"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_PERMIT_ADDRESS</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 5 commit (deny policy)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 5d: wilma - edit into visible; 'set ?' shows data/extra (permitted subtree)"
expectpart "$(printf 'edit visible\nset ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "data" "extra"

new "Test 5e: wilma - edit into devices; 'set ?' shows device (ancestor of permitted path)"
expectpart "$(printf 'edit devices\nset ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "device"

new "Test 5f: wilma - edit into devices device x; 'set ?' shows address, NOT description or settings"
expectpart "$(printf 'edit devices\nedit device x\nset ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "address" --not-- "description" --not-- "settings"

new "Test 5g: admin - edit into devices device x; 'set ?' shows all leaves"
expectpart "$(printf 'edit devices\nedit device x\nset ?' | $clixon_cli -f $cfg -U admin 2>&1)" 0 "address" "description" "settings"

# --- Test 6: permit-default, deny /devices/device/settings (inside list) ---
new "Test 6: Load NACM read-default=permit, deny /devices/device/settings"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_DENY_DEVICE_SETTINGS</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 6 commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 6a: wilma - 'set ?' shows devices (top-level ancestor of deny)"
expectpart "$(echo 'set ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "devices"

new "Test 6b: wilma - 'set devices device x ?' shows address and description, NOT settings"
expectpart "$(printf 'set devices device x ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "address" "description" --not-- "settings"

new "Test 6c: wilma - edit into devices device x; 'set ?' shows address/description, NOT settings"
expectpart "$(printf 'edit devices\nedit device x\nset ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "address" "description" --not-- "settings"

new "Test 6d: admin - 'set devices device x ?' shows all (address, description, settings)"
expectpart "$(printf 'set devices device x ?' | $clixon_cli -f $cfg -U admin 2>&1)" 0 "address" "description" "settings"

# --- Test 7: deny-default, permit only /devices/device/settings/enabled (deeply nested in list) ---
new "Test 7: Load NACM read-default=deny, permit only /devices/device/settings/enabled"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_PERMIT_SETTINGS_ENABLED</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 7 commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 7a: wilma - 'set ?' shows devices (ancestor of permit), NOT public/visible/mgmt/secret"
expectpart "$(echo 'set ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "devices" --not-- "public" --not-- "visible" --not-- "mgmt" --not-- "secret"

new "Test 7b: wilma - 'set devices device x ?' shows settings (ancestor), NOT address or description"
expectpart "$(printf 'set devices device x ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "settings" --not-- "address" --not-- "description"

new "Test 7c: wilma - 'set devices device x settings ?' shows enabled, NOT priority"
expectpart "$(printf 'set devices device x settings ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "enabled" --not-- "priority"

new "Test 7d: wilma - edit into devices device x; 'set ?' shows settings, NOT address/description"
expectpart "$(printf 'edit devices\nedit device x\nset ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "settings" --not-- "address" --not-- "description"

new "Test 7e: wilma - edit into devices device x settings; 'set ?' shows enabled, NOT priority"
expectpart "$(printf 'edit devices\nedit device x\nedit settings\nset ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 "enabled" --not-- "priority"

new "Test 7f: admin - 'set devices device x settings ?' shows all (enabled and priority)"
expectpart "$(printf 'set devices device x settings ?' | $clixon_cli -f $cfg -U admin 2>&1)" 0 "enabled" "priority"

# --- Test 8: CLICON_NACM_AUTOCLI=false disables filtering ---
# Load a deny rule for /secret, but with NACM_AUTOCLI disabled the CLI must show /secret anyway
new "Test 8: Load NACM read-default=permit, deny /secret"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>$NACM_DENY_SECRET</config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 8 commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Test 8a: wilma - NACM_AUTOCLI enabled (default): 'set ?' hides secret"
expectpart "$(echo 'set ?' | $clixon_cli -f $cfg -U wilma 2>&1)" 0 --not-- "secret"

new "Test 8b: wilma - NACM_AUTOCLI=false: 'set ?' shows secret despite deny rule"
expectpart "$(echo 'set ?' | $clixon_cli -f $cfg -o CLICON_NACM_AUTOCLI=false -U wilma 2>&1)" 0 "secret"

# --- Cleanup ---
if [ $BE -ne 0 ]; then
    new "kill backend"
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
