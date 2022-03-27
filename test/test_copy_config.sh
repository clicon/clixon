#!/usr/bin/env bash
# RFC 6241:
# 7.3   - Even if it advertises the :writable-running capability, a device
#         MAY choose not to support the <running/> configuration datastore
#         as the <target> parameter of a <copy-config> operation.
#       - If the <source> and <target> parameters identify the same URL or
#         configuration datastore, an error MUST be returned with an error-
#         tag containing "invalid-value".
# 8.3.5.1 The candidate configuration can be used as a source or target 
# 8.4.1   If :startup capability is advertized, <copy-config> from running to
#         startup is also necessary
# 8.8.5.2 :url capability <copy-config> accepts <url> element as value of
#         the <source> and the <target> parameters.
#
# The test checks that these are allowed:
#   running->startup
#   running->candidate
#   candidate->startup
#   startup->candidate
# And checks that copying to running is not allowed

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example
# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml

fyang=$dir/ietf-interfaces@2019-03-04.yang

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none true)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  $RESTCONFIG
</clixon-config>
EOF

# Stub ietf-interfaces for test
cat <<EOF > $fyang
module ietf-interfaces {
  yang-version 1.1;
  namespace "urn:ietf:params:xml:ns:yang:ietf-interfaces";
  prefix if;
  revision "2019-03-04";
  identity interface-type {
    description
      "Base identity from which specific interface types are
       derived.";
  }
  identity fddi {
     base interface-type;
  }
  container interfaces {
    description      "Interface parameters.";
    list interface {
      key "name";
      leaf name {
        type string;
      }
      leaf type {
        type identityref {
          base interface-type;
        }
        mandatory true;
      }
      leaf enabled {
        type boolean;
        default "true";
      }
    }
  }
}
EOF

# Create empty startup
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}/>
EOF

# rm candidate and running
rm -f $dir/running_db
rm -f $dir/candidate_db

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

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

new "Add config to candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"create\"><name>eth/0/0</name><type>if:fddi</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit to running"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Delete candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name>eth/0/0</name><type>if:fddi</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Here startup and candidate are empty, only running has content
# test running->startup and running->candidate
new "Check candidate empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "Check startup empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><startup/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "copy running->startup"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><copy-config><target><startup/></target><source><running/></source></copy-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "copy running->candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><copy-config><target><candidate/></target><source><running/></source></copy-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Here startup and candidate have content
new "Check candidate content"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>if:fddi</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>"

new "Check startup content"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><startup/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>if:fddi</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>"

new "Delete startup"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><delete-config><target><startup/></target></delete-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Here startup is empty and candidate has content
# test candidate->startup
new "Check startup empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><startup/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "copy candidate->startup"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><copy-config><target><startup/></target><source><candidate/></source></copy-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check startup content"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><startup/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>if:fddi</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>"

new "Delete candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name>eth/0/0</name><type>if:fddi</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Here candidate is empty and startup has content
# test startup->candidate
new "Check candidate empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "copy startup->candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><copy-config><target><candidate/></target><source><startup/></source></copy-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check candidate content"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>if:fddi</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>"

# Negative test: check copying to running is not allowed
new "Delete candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name>eth/0/0</name><type>if:fddi</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit to running"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Here running is empty
new "Check running empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

# Add to candidate
new "copy startup->candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><copy-config><target><candidate/></target><source><startup/></source></copy-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

if ! $YANG_UNKNOWN_ANYDATA ; then
    new "copy startup->running not allowed"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><copy-config><target><running/></target><source><startup/></source></copy-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>running</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: running with parent: target in namespace: urn:ietf:params:xml:ns:netconf:base:1.0</error-message></rpc-error></rpc-reply>"
fi

# restconf copy
new "restconf copy-config smoketest, json"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://127.0.0.1/restconf/operations/ietf-netconf:copy-config -d '{"ietf-netconf:input": {"target": {"startup": [null]},"source": {"running": [null]}}}')" 0 "HTTP/$HVER 204"

new "restconf copy-config smoketest, xml"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://127.0.0.1/restconf/operations/ietf-netconf:copy-config -d '<input xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><target><startup></startup></target><source><running></running></source></input>')" 0 "HTTP/$HVER 204"

# Here running is empty
new "Check running empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

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

# Set by restconf_config
unset RESTCONFIG

new "Endtest"
endtest

rm -rf $dir
