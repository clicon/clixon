#!/usr/bin/env bash
# Yang leafref + state tests
# The difficulty here is a "leafref" in state data that references config-data.
# Problem being that config-data from running needs to be mergedwith state data and filtered/cropped
# correctly
#
# The YANG has two parts, one config part (sender-config) and one state part (sender-state)
# The leafref in the sender-state part references a leaf in the sender-config part
# Netconf tests are made to get state, state+config, using content attribute config/nonconfig/all
# with different paths.
# Using the -sS <file> state capability of the main example, that is why CLICON_BACKEND_DIR is
# /usr/local/lib/$APPNAME/backend so that the main backend plugins is included.
# These tests require VALIDATE_STATE_XML to be set

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fstate=$dir/state.xml
fyang=$dir/leafref.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

# NOTE prefix "example" used in module different from "ex" used in mport of that module
cat <<EOF > $fyang
module leafref{
    yang-version 1.1;
    namespace "urn:example:example";
    prefix ex;
    list sender-config{
        description "Main config of senders";
        key name;
        leaf name{
           type string;
        }
    }
    list sender-state{
        description "State referencing configured senders";
        config false;
        key ref;
        leaf ref{
 	   type leafref {
	      path "/ex:sender-config/ex:name";
	   }
        }
    }
}
EOF

# This is state data written to file that backend reads from (on request)
cat <<EOF > $fstate
   <sender-state xmlns="urn:example:example">
      <ref>x</ref>
   </sender-state>
EOF

new "test params: -f $cfg -- -sS $fstate"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg -- -sS $fstate"
    start_backend -s init -f $cfg -- -sS $fstate
    new "waiting"
    wait_backend
fi

# Test top-level, default prefix, wrong leafref prefix and typedef path
XML=$(cat <<EOF
   <sender-config xmlns="urn:example:example">
      <name>x</name>
   </sender-config>
EOF
)

new "leafref config sender x"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config>$XML</config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Get path=/, state vs config
new "netconf get / config+state"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="all"><filter type="xpath" select="/"/></get></rpc>]]>]]>' '^<rpc-reply><data><sender-config xmlns="urn:example:example"><name>x</name></sender-config><sender-state xmlns="urn:example:example"><ref>x</ref></sender-state></data></rpc-reply>]]>]]>$'

new "netconf get / state-only"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="nonconfig"><filter type="xpath" select="/"/></get></rpc>]]>]]>' '^<rpc-reply><data><sender-state xmlns="urn:example:example"><ref>x</ref></sender-state></data></rpc-reply>]]>]]>$'

new "netconf get / config-only"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="config"><filter type="xpath" select="/"/></get></rpc>]]>]]>' '^<rpc-reply><data><sender-config xmlns="urn:example:example"><name>x</name></sender-config></data></rpc-reply>]]>]]>$'

# Get path=/sender-state, state vs config
new "netconf get /sender-state config+state"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="all"><filter type="xpath" select="/ex:sender-state" xmlns:ex="urn:example:example"/></get></rpc>]]>]]>' '^<rpc-reply><data><sender-state xmlns="urn:example:example"><ref>x</ref></sender-state></data></rpc-reply>]]>]]>$'

new "netconf get /sender-state state-only"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="nonconfig"><filter type="xpath" select="/ex:sender-state" xmlns:ex="urn:example:example"/></get></rpc>]]>]]>' '^<rpc-reply><data><sender-state xmlns="urn:example:example"><ref>x</ref></sender-state></data></rpc-reply>]]>]]>$'

new "netconf get /sender-state config-only"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="config"><filter type="xpath" select="/ex:sender-state" xmlns:ex="urn:example:example"/></get></rpc>]]>]]>' '^<rpc-reply><data/></rpc-reply>]]>]]>$'

# Get path=/sender-config, state vs config
new "netconf get /sender-config config+state"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="all"><filter type="xpath" select="/ex:sender-config" xmlns:ex="urn:example:example"/></get></rpc>]]>]]>' '^<rpc-reply><data><sender-config xmlns="urn:example:example"><name>x</name></sender-config></data></rpc-reply>]]>]]>$'

new "netconf get /sender-config state-only"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="nonconfig"><filter type="xpath" select="/ex:sender-config" xmlns:ex="urn:example:example"/></get></rpc>]]>]]>' '^<rpc-reply><data/></rpc-reply>]]>]]>$'

new "netconf get /sender-config config-only"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="config"><filter type="xpath" select="/ex:sender-config" xmlns:ex="urn:example:example"/></get></rpc>]]>]]>' '^<rpc-reply><data><sender-config xmlns="urn:example:example"><name>x</name></sender-config></data></rpc-reply>]]>]]>$'

# Negative tests, 
# Double xmlns attribute
cat <<EOF > $fstate
   <sender-config xmlns="urn:example:example">
      <name>x</name>
   </sender-config>
EOF

new "Merge same tree - check double xmlns attribute"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="all"><filter type="xpath" select="/"/></get></rpc>]]>]]>' '^<rpc-reply><data><sender-config xmlns="urn:example:example"><name>x</name></sender-config></data></rpc-reply>]]>]]>$'

# Back to original
cat <<EOF > $fstate
   <sender-state xmlns="urn:example:example">
      <ref>x</ref>
   </sender-state>
EOF

# delete x, add y
XML=$(cat <<EOF
   <sender-config xmlns="urn:example:example" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0" nc:operation="delete">
      <name>x</name>
   </sender-config>
   <sender-config xmlns="urn:example:example">
      <name>y</name>
   </sender-config>
EOF
)
# Negative tests, start with remove x and and add y instead
new "leafref config delete sender x add y"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config>$XML</config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Leafref wrong
new "netconf get / config+state should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="all"><filter type="xpath" select="/"/></get></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-info><bad-element>x</bad-element></error-info><error-severity>error</error-severity><error-message>Leafref validation failed: No leaf x matching path /ex:sender-config/ex:name. Internal error, state callback returned invalid XML</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf get / state-only should fail"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="nonconfig"><filter type="xpath" select="/"/></get></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-info><bad-element>x</bad-element></error-info><error-severity>error</error-severity><error-message>Leafref validation failed: No leaf x matching path /ex:sender-config/ex:name. Internal error, state callback returned invalid XML</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf get / config-only ok"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="config"><filter type="xpath" select="/"/></get></rpc>]]>]]>' '^<rpc-reply><data><sender-config xmlns="urn:example:example"><name>y</name></sender-config></data></rpc-reply>]]>]]>$'

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
stop_backend -f $cfg

rm -rf $dir
