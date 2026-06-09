#!/usr/bin/env bash
# Test NACM enable-external-groups (RFC 8341 §3.2.2)
#
# When enable-external-groups=true the backend augments the static NACM
# user-name lookup with the OS group memberships of the connecting peer.
#
# Test matrix:
#   Nr | external | peer OS group | static user-name | result
#   ---+----------+---------------+------------------+--------
#   1. | true     | match         | no               | permit
#   2. | false    | match         | no               | deny
#   3. | true     | no            | match            | permit (regresssion)
#   4. | true     | no            | no               | deny
#
# Uses raw UNIX socket (clixon_util_socket) with NACM credentials=exact so that
# peer identity comes from the socket credential, not the RPC attribute.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang

NACMUSER=$(whoami)

let nr=0

# Determine a secondary OS group for the external-groups test.
# A secondary group (different from the primary) is required so that the test
# can configure a NACM group whose name matches one of the peer's OS groups
# without that username also appearing in a NACM user-name entry.
# If the user belongs only to their primary group (e.g. a minimal container
# user) the test is skipped — see test/README.md for the requirement.
PRIMARYGROUP=$(id -gn)
SECONDARYGROUP=$(id -Gn | tr ' ' '\n' | grep -v "^${PRIMARYGROUP}$" | head -1)
if [ -z "$SECONDARYGROUP" ]; then
    echo "...skipped: $NACMUSER has no secondary OS group (primary: $PRIMARYGROUP); add the user to a secondary group to run this test"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

cat <<EOF > $fyang
module nacm-example {
  yang-version 1.1;
  namespace "urn:example:nacm";
  prefix nex;
  import ietf-netconf-acm {
    prefix nacm;
  }
  leaf x {
    type int32;
    description "test data node";
  }
}
EOF

OK='^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><data><x xmlns="urn:example:nacm">42</x></data></rpc-reply>$'
ERROR='^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag>'

#----------------------------------------------------------------------
# setup: start backend, load x=42 and given NACM XML
#----------------------------------------------------------------------
function setup() {
    local nacmxml=$1

    cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK_FAMILY>UNIX</CLICON_SOCK_FAMILY>
  <CLICON_SOCK>$dir/backend.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
  <CLICON_NACM_CREDENTIALS>exact</CLICON_NACM_CREDENTIALS>
</clixon-config>
EOF

    if [ $BE -ne 0 ]; then
        new "kill old backend"
        sudo clixon_backend -zf $cfg
        if [ $? -ne 0 ]; then err; fi
        new "start backend -s init -f $cfg"
        start_backend -s init -f $cfg
    fi

    let nr++
    new "wait backend $nr"
    wait_backend

    new "load x=42 and NACM config"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
        "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:nacm\">42</x>${nacmxml}</config></edit-config></rpc>" \
        "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "commit"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
        "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
}

function teardown() {
    if [ $BE -ne 0 ]; then
        new "Kill backend"
        stop_backend -f $cfg
    fi
}

# Send get-config via raw UNIX socket with given RPC username; check output
function testget() {
    local username=$1
    local ex=$2
    local XML="<rpc $DEFAULTNS username=\"$username\"><get-config><source><running/></source><filter type=\"xpath\" select=\"/ex:x\" xmlns:ex=\"urn:example:nacm\"/></get-config></rpc>"
    expecteof_netconf "$clixon_util_socket -a UNIX -s $dir/backend.sock -D $DBG" 0 "" "$XML" "$ex"
}

new "test params: -f $cfg  user=$NACMUSER  osgroup=$SECONDARYGROUP"

# Generate NACM XML block for a single group and rule-list permitting get/get-config.
# Arguments:
#   $1 - enable-external-groups value (true|false)
#   $2 - NACM group name
#   $3 - user-name to add inside the group, or "" for none (external-only)
function nacm_config() {
    local extgroups=$1
    local groupname=$2
    local username=$3
    local usertag=""
    if [ -n "$username" ]; then
        usertag="<user-name>${username}</user-name>"
    fi
    echo "<nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\">
  <enable-nacm>true</enable-nacm>
  <read-default>permit</read-default>
  <write-default>deny</write-default>
  <exec-default>deny</exec-default>
  <enable-external-groups>${extgroups}</enable-external-groups>
  <groups>
    <group>
      <name>${groupname}</name>
      ${usertag}
    </group>
  </groups>
  <rule-list>
    <name>${groupname}-acl</name>
    <group>${groupname}</group>
    <rule>
      <name>permit-get-config</name>
      <rpc-name>get-config</rpc-name>
      <module-name>*</module-name>
      <access-operations>exec</access-operations>
      <action>permit</action>
    </rule>
    <rule>
      <name>permit-get</name>
      <rpc-name>get</rpc-name>
      <module-name>*</module-name>
      <access-operations>exec</access-operations>
      <action>permit</action>
    </rule>
  </rule-list>
</nacm>"
}

#----------------------------------------------------------------------
# Test 1: enable-external-groups=true
# NACM group name equals SECONDARYGROUP; no user-name entries.
# Peer is NACMUSER who belongs to SECONDARYGROUP via OS.
# Expected: access PERMITTED (OS group membership grants access).
#----------------------------------------------------------------------
new "Test 1: setup enable-external-groups=true, group=$SECONDARYGROUP (no user-name)"
setup "$(nacm_config true "$SECONDARYGROUP" "")"

new "Test 1: $NACMUSER not in user-name but member of OS group $SECONDARYGROUP → permit"
testget "$NACMUSER" "$OK"

teardown

#----------------------------------------------------------------------
# Test 2: enable-external-groups=false
# Identical NACM config but external groups disabled.
# Expected: access DENIED (username not in any user-name list).
#----------------------------------------------------------------------
new "Test 2: setup enable-external-groups=false, group=$SECONDARYGROUP (no user-name)"
setup "$(nacm_config false "$SECONDARYGROUP" "")"

new "Test 2: $NACMUSER not in user-name, external-groups=false → deny"
testget "$NACMUSER" "$ERROR"

teardown

#----------------------------------------------------------------------
# Test 3: static user-name with enable-external-groups=true (regression)
# Username IS listed in user-name; should still be permitted.
#----------------------------------------------------------------------
new "Test 3: setup static user-name with enable-external-groups=true"
setup "$(nacm_config true "mygroup" "$NACMUSER")"

new "Test 3: $NACMUSER in static user-name list → permit"
testget "$NACMUSER" "$OK"

teardown

#----------------------------------------------------------------------
# Test 4: enable-external-groups=true but peer's OS groups do NOT match
# any NACM group. Use a synthetic group name that cannot exist on any OS.
# Expected: access DENIED.
#----------------------------------------------------------------------
new "Test 4: setup enable-external-groups=true, group=no-such-os-group"
setup "$(nacm_config true "no-such-os-group-$$" "")"

new "Test 4: $NACMUSER not member of NACM group (no OS match) → deny"
testget "$NACMUSER" "$ERROR"

teardown

rm -rf $dir

unset NACMUSER
unset PRIMARYGROUP
unset SECONDARYGROUP

new "endtest"
endtest
