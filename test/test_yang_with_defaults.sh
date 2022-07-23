#!/usr/bin/env bash


# Test of the IETF rfc6243: With-defaults Capability for NETCONF
#
# Test cases below follows the RFC.
#

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example-default.yang
fstate=$dir/state.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
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
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
</clixon-config>
EOF

# A.1.  Example YANG Module
# The following YANG module defines an example interfaces table to
# demonstrate how the <with-defaults> parameter behaves for a specific
# data model.
cat <<EOF > $fyang
module example {

     namespace "http://example.com/ns/interfaces";

     prefix exam;

     typedef status-type {
        description "Interface status";
        type enumeration {
          enum ok;
          enum 'waking up';
          enum 'not feeling so good';
          enum 'better check it out';
          enum 'better call for help';
        }
        default ok;
     }

     container interfaces {
         description "Example interfaces group";

         list interface {
           description "Example interface entry";
           key name;

           leaf name {
             description
               "The administrative name of the interface.
                This is an identifier that is only unique
                within the scope of this list, and only
                within a specific server.";
             type string {
               length "1 .. max";
             }
           }

           leaf mtu {
             description
               "The maximum transmission unit (MTU) value assigned to
                this interface.";
             type uint32;
             default 1500;
           }

           leaf status {
             description
               "The current status of this interface.";
             type status-type;
             config false;
           }
         }
       }
     }
EOF

# A.2.  Example  Data Set

EXAMPLENS="xmlns=\"http://example.com/ns/interfaces\""

XML="<interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu></interface>\
<interface><name>eth1</name></interface>\
<interface><name>eth2</name><mtu>9000</mtu></interface>\
<interface><name>eth3</name><mtu>1500</mtu></interface>\
</interfaces>"

cat <<EOF > $fstate
<interfaces xmlns="http://example.com/ns/interfaces">
<interface><name>eth2</name><status>not feeling so good</status></interface>
<interface><name>eth3</name><status>waking up</status></interface>
</interfaces>
EOF


db=startup
if [ $db = startup ]; then
    sudo echo "<${DATASTORE_TOP}>$XML</${DATASTORE_TOP}>" > $dir/startup_db
fi
if [ $BE -ne 0 ]; then     # Bring your own backend
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s $db -f $cfg"
    start_backend  -s $db -f $cfg -- -sS $fstate
fi

new "wait backend"
wait_backend

# permission kludges
new "chmod datastores"
sudo chmod 666 $dir/running_db
if [ $? -ne 0 ]; then
    err1 "chmod $dir/running_db"
fi
sudo chmod 666 $dir/startup_db
if [ $? -ne 0 ]; then
    err1 "chmod $dir/startup_db"
fi

new "Checking startup unchanged"
ret=$(diff $dir/startup_db <(echo "<${DATASTORE_TOP}>$XML</${DATASTORE_TOP}>"))
if [ $? -ne 0 ]; then
    err "<${DATASTORE_TOP}>$XML</${DATASTORE_TOP}>" "$ret"
fi

new "Checking running unchanged"
ret=$(diff $dir/running_db <(echo -n "<${DATASTORE_TOP}>$XML</${DATASTORE_TOP}>"))
if [ $? -ne 0 ]; then
    err "<${DATASTORE_TOP}>$XML</${DATASTORE_TOP}>" "$ret"
fi

new "rfc4243 4.3.  Capability Identifier"
expecteof "$clixon_netconf -ef $cfg" 0 "$DEFAULTHELLO" \
"<capability>urn:ietf:params:netconf:capability:with-defaults:1.0?basic-mode=explicit</capability>"

new "rfc6243 3.1.  'report-all' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><mtu>1500</mtu><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
</interfaces></data></rpc-reply>"

new "rfc6243 3.2.  'trim' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">trim</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag>\
<error-severity>error</error-severity>\
<error-message>with-defaults retrieval mode \"trim\" is not supported</error-message></rpc-error></rpc-reply>"

new "rfc6243 3.3.  'explicit' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">explicit</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
</interfaces></data></rpc-reply>"

new "rfc6243 3.4.  'report-all-tagged' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all-tagged</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag>\
<error-severity>error</error-severity>\
<error-message>with-defaults retrieval mode \"report-all-tagged\" is not supported</error-message></rpc-error></rpc-reply>"

new "rfc6243 2.3.1.  'explicit' Basic Mode Retrieval"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><mtu>1500</mtu><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
</interfaces></data></rpc-reply>" ""

new "rfc6243 2.3.3.  'explicit' <edit-config> and <copy-config> Behavior (part 1): create explicit node"
# A valid 'create' operation attribute for a data node that has
# been set by a client to its schema default value MUST fail with a
# 'data-exists' error-tag.
# (test: try to create mtu=3000 on interface eth3)
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>\
<interfaces $EXAMPLENS xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\">\
<interface><name>eth3</name><mtu nc:operation=\"create\">3000</mtu></interface>\
</interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "" \
"<rpc-reply $DEFAULTNS><rpc-error>\
<error-type>application</error-type>\
<error-tag>data-exists</error-tag>\
<error-severity>error</error-severity>\
<error-message>Data already exists; cannot create new resource</error-message>\
</rpc-error></rpc-reply>"
# nothing to commit here, but just to verify
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
# verify no change
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><mtu>1500</mtu><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
</interfaces></data></rpc-reply>" ""

new "rfc6243 2.3.3.  'explicit' <edit-config> and <copy-config> Behavior (part 2): create default node"
# A valid 'create' operation attribute for a
# data node that has been set by the server to its schema default value
# MUST succeed.
# (test: set mtu=3000 on interface eth1)
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>\
<interfaces $EXAMPLENS xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\">\
<interface><name>eth1</name><mtu nc:operation=\"create\">3000</mtu></interface>\
</interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
# commit change
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
# verify that the mtu value has changed
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><mtu>3000</mtu><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
</interfaces></data></rpc-reply>" ""

new "rfc6243 2.3.3.  'explicit' <edit-config> and <copy-config> Behavior (part 3): delete explicit node"
#  A valid 'delete' operation attribute for a data node
#  that has been set by a client to its schema default value MUST
#  succeed.
# (test: try to delete mtu on interface eth1)
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>\
<interfaces $EXAMPLENS  xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\">\
<interface><name>eth1</name><mtu nc:operation=\"delete\"></mtu></interface>\
</interfaces></config><default-operation>none</default-operation></edit-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
# commit delete
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
# check thet the default mtu vale has been restored
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><mtu>1500</mtu><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
</interfaces></data></rpc-reply>" ""

new "rfc6243 2.3.3.  'explicit' <edit-config> and <copy-config> Behavior (part 4): delete default node"
# A valid 'delete' operation attribute for a data node that
# has been set by the server to its schema default value MUST fail with
# a 'data-missing' error-tag.
#(test: try to delete default mtu on interface eth1)
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>\
<interfaces $EXAMPLENS  xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\">\
<interface ><name>eth1</name><mtu nc:operation=\"delete\">1500</mtu></interface>\
</interfaces></config><default-operation>none</default-operation></edit-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><rpc-error>\
<error-type>application</error-type>\
<error-tag>data-missing</error-tag>\
<error-severity>error</error-severity>\
<error-message>Data does not exist; cannot delete resource</error-message>\
</rpc-error></rpc-reply>"
# nothing to commit
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
# verify that the configuration has not changed
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><mtu>1500</mtu><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
</interfaces></data></rpc-reply>" ""


if [ $BE -ne 0 ]; then     # Bring your own backend
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
fi

rm -rf $dir

unset ret

new "endtest"
endtest
