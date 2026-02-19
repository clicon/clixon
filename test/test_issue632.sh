#!/usr/bin/env bash
# Test for issue #632: leafref instance-required with state
# This tests leafref in CONFIG data that references STATE data
# which is the opposite of test_leafref_state.sh (leafref in state referencing config)
#
# Problem: User has a leafref in config data that references a leaf in a "config false" container.
# During validation, Clixon fails with "instance-required" error even though the state data exists.
#
# Example YANG from issue:
#   leaf mac-address {
#     type leafref {
#       path "../state/mac-address-list";
#     }
#   }
#   container state {
#     config false;
#     leaf mac-address-list {
#       type enumeration { enum "00:00:5e:00:01:32"; }
#     }
#   }

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fstate=$dir/state.xml
fyang=$dir/issue632.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
  <CLICON_STREAM_DISCOVERY_RFC8040>false</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_NETCONF_MONITORING>false</CLICON_NETCONF_MONITORING>
</clixon-config>
EOF

# YANG module with leafref in config referencing state data
cat <<EOF > $fyang
module issue632 {
    yang-version 1.1;
    namespace "urn:example:issue632";
    prefix i632;

    grouping control-link-common-config {
        description "HA Control link configuration parameters";

        leaf local-ip {
            type string;
            description "Local ip-address of control-link interface";
        }

        leaf virtual-ip {
            type string;
            description "Virtual ip-address of control-link interface";
        }

        leaf peer-ip {
            type string;
            description "IP-address of neighbor interface in ha-pair";
        }

        leaf mac-address {
            description "MAC address of the interface";
            type leafref {
                path "../state/mac-address-list";
            }
        }

        container state {
            config false;
            description "Operational state data related to HA control link";

            leaf mac-address-list {
                type enumeration {
                    enum "00:00:5e:00:01:32";
                    enum "00:00:5e:00:01:33";
                    enum "00:00:5e:00:01:34";
                }
                description "Available MAC addresses";
            }
        }
    }

    container control-link {
        description "HA control link configuration";
        uses control-link-common-config;
    }
}
EOF

# This is state data written to file that backend reads from (on request)
# The state container contains available MAC addresses
cat <<EOF > $fstate
   <control-link xmlns="urn:example:issue632">
      <state>
         <mac-address-list>00:00:5e:00:01:32</mac-address-list>
      </state>
   </control-link>
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
fi

new "wait backend"
wait_backend

# First verify that state data is accessible
new "netconf get state data"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get content=\"nonconfig\"><filter type=\"xpath\" select=\"/\"/></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><control-link xmlns=\"urn:example:issue632\"><state><mac-address-list>00:00:5e:00:01:32</mac-address-list></state></control-link></data></rpc-reply>"

# Now try to configure with a MAC address that exists in state data
# This is the issue #632 - this SHOULD work but currently fails with instance-required error
XML=$(cat <<EOF
   <control-link xmlns="urn:example:issue632">
      <local-ip>192.168.1.1/24</local-ip>
      <virtual-ip>192.168.1.100/24</virtual-ip>
      <peer-ip>192.168.1.2/24</peer-ip>
      <mac-address>00:00:5e:00:01:32</mac-address>
   </control-link>
EOF
)

new "Issue #632: Configure with MAC address from state data - should work"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$XML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Issue #632: Commit configuration with leafref to state - should work"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get config+state after commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get content=\"all\"><filter type=\"xpath\" select=\"/\"/></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><control-link xmlns=\"urn:example:issue632\"><local-ip>192.168.1.1/24</local-ip><virtual-ip>192.168.1.100/24</virtual-ip><peer-ip>192.168.1.2/24</peer-ip><mac-address>00:00:5e:00:01:32</mac-address><state><mac-address-list>00:00:5e:00:01:32</mac-address-list></state></control-link></data></rpc-reply>"

# Test with a MAC address that does NOT exist in state - should fail
XML=$(cat <<EOF
   <control-link xmlns="urn:example:issue632">
      <local-ip>192.168.1.1/24</local-ip>
      <virtual-ip>192.168.1.100/24</virtual-ip>
      <peer-ip>192.168.1.2/24</peer-ip>
      <mac-address>00:00:5e:00:01:99</mac-address>
   </control-link>
EOF
)

new "Issue #632: Configure with invalid MAC address - should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$XML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Issue #632: Commit with invalid MAC address should fail with instance-required"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>instance-required</error-app-tag>" ""

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Test with a different valid MAC address
XML=$(cat <<EOF
   <control-link xmlns="urn:example:issue632">
      <local-ip>192.168.1.1/24</local-ip>
      <virtual-ip>192.168.1.100/24</virtual-ip>
      <peer-ip>192.168.1.2/24</peer-ip>
      <mac-address>00:00:5e:00:01:33</mac-address>
   </control-link>
EOF
)

# Update state to include another MAC address
cat <<EOF > $fstate
   <control-link xmlns="urn:example:issue632">
      <state>
         <mac-address-list>00:00:5e:00:01:33</mac-address-list>
      </state>
   </control-link>
EOF

new "Issue #632: Configure with different valid MAC address"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$XML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Issue #632: Commit with different valid MAC address - should work"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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

rm -rf $dir

new "endtest"
endtest

