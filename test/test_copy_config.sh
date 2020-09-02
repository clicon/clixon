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

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
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
</clixon-config>
EOF

# Create empty startup
cat <<EOF > $dir/startup_db
<config/>
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

    new "waiting"
    wait_backend
fi

new "Add config to candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"create\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit to running"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Delete candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# Here startup and candidate are empty, only running has content
# test running->startup and running->candidate
new "Check candidate empty"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

new "Check startup empty"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><startup/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

new "copy running->startup"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><copy-config><target><startup/></target><source><running/></source></copy-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "copy running->candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><copy-config><target><candidate/></target><source><running/></source></copy-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# Here startup and candidate have content
new "Check candidate content"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

new "Check startup content"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><startup/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

new "Delete startup"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><delete-config><target><startup/></target></delete-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# Here startup is empty and candidate has content
# test candidate->startup
new "Check startup empty"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><startup/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

new "copy candidate->startup"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><copy-config><target><startup/></target><source><candidate/></source></copy-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Check startup content"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><startup/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

new "Delete candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# Here candidate is empty and startup has content
# test startup->candidate
new "Check candidate empty"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

new "copy startup->candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><copy-config><target><candidate/></target><source><startup/></source></copy-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Check candidate content"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth/0/0</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data></rpc-reply>]]>]]>$"

# Negative test: check copying to running is not allowed
new "Delete candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><interface nc:operation=\"delete\"><name>eth/0/0</name><type>ex:eth</type></interface></interfaces></config><default-operation>none</default-operation> </edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit to running"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# Here running is empty
new "Check running empty"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><running/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

# Add to candidate
new "copy startup->candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><copy-config><target><candidate/></target><source><startup/></source></copy-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

if ! $YANG_UNKNOWN_ANYDATA ; then
new "copy startup->running not allowed"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><copy-config><target><running/></target><source><startup/></source></copy-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>running</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: running with parent: target in namespace: urn:ietf:params:xml:ns:netconf:base:1.0</error-message></rpc-error></rpc-reply>]]>]]>$"
fi

# Here running is empty
new "Check running empty"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS message-id=\"101\"><get-config><source><running/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS message-id=\"101\"><data/></rpc-reply>]]>]]>$"

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
