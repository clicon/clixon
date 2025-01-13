#!/usr/bin/env bash
# Test augmented state
# Use main example -- -sS option to add state via a file
#
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example-augment.yang
fyang2=$dir/example-lib.yang
fstate=$dir/state.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>a:test</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_STREAM_DISCOVERY_RFC8040>false</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_NETCONF_MONITORING>false</CLICON_NETCONF_MONITORING>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

# This is the lib function with the base container
cat <<EOF > $fyang2
module example-lib {
  yang-version 1.1;
  namespace "urn:example:lib";
  prefix lib;
  revision "2019-03-04";
  container global-state {
    config false;
    leaf gbds{
      description "Global base default state";
      type string;
      default "gbds";
    }     
    leaf gbos{
      description "Global base optional state";
      type string;
    }     
    container nopres{
      description "This should be removed";
    }
  }
  container base-config {
    list parameter{
      key name;
      leaf name{
        type string;
      }
      container param-state {
        config false;
        leaf lbds{
          description "Local base default state";
          type string;
          default "lbds";
        }
        leaf lbos{
          description "Local base optional state";
          type string;
        }
      }
    }    
  }
}
EOF

# This is the main module where the augment exists
cat <<EOF > $fyang
module example-augment {
  yang-version 1.1;
  namespace "urn:example:augment";
  prefix aug;
  import example-lib {
     prefix lib;
  }
  revision "2020-09-25";
  /* Augments global state */
  augment "/lib:global-state" {
    leaf gads{
      description "Global augmented default state";
      type string;
      default "gads";
    }     
    leaf gaos{
      description "Global augmented optional state";
      type string;
    }     
  }
  /* Augments state in config in-line */
  augment "/lib:base-config/lib:parameter/lib:param-state" {
    leaf lads{
      description "Local augmented default state";
      type string;
      default "lads";
    }     
    leaf laos{
      description "Local augmented optional state";
      type string;
    }     
  }
}
EOF

# Get config and state
# Arguments
# - expected config
# - expected state
function testrun()
{
    config=$1
    state=$2

    new "get config"
    if [ -z "$config" ]; then
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">explicit</with-defaults></get-config></rpc>" "^<rpc-reply $DEFAULTNS><data/></rpc-reply>$"
    else
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">explicit</with-defaults></get-config></rpc>" "^<rpc-reply $DEFAULTNS><data>$config</data></rpc-reply>$"
    fi

    new "get state"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">explicit</with-defaults></get></rpc>" "^<rpc-reply $DEFAULTNS><data>$state</data></rpc-reply>$"
}

new "test params: -f $cfg"

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

#-----------------------------
new "1. Empty config/state, expect global default state"

CONFIG=""

cat <<EOF > $fstate
EOF

EXPSTATE=$(cat <<EOF
<global-state xmlns="urn:example:lib"><gbds>gbds</gbds><gads xmlns="urn:example:augment">gads</gads></global-state>
EOF
)

testrun "$CONFIG" "$EXPSTATE"

#-----------------------------
new "2. Empty config/top-level state, expect global default state"
cat <<EOF > $fstate
<global-state xmlns="urn:example:lib"/>
EOF

testrun "$CONFIG" "$EXPSTATE"

#-----------------------------
new "3. Empty config/top-level w non-presence state, expect global default state"
cat <<EOF > $fstate
<global-state xmlns="urn:example:lib">
   <nopres/>
</global-state>
EOF

testrun "$CONFIG" "$EXPSTATE"

#-----------------------------
new "4. Empty config + optional state, expect global default + optional state"
cat <<EOF > $fstate
<global-state xmlns="urn:example:lib">
  <gbos>gbos</gbos>
  <gaos xmlns="urn:example:augment">gaos</gaos>
</global-state>
EOF

# Note Expect gbds(default) + gbos(optional), the latter given by file above
EXPSTATE=$(cat <<EOF
<global-state xmlns="urn:example:lib"><gbds>gbds</gbds><gbos>gbos</gbos><gads xmlns="urn:example:augment">gads</gads><gaos xmlns="urn:example:augment">gaos</gaos></global-state>
EOF
)

testrun "$CONFIG" "$EXPSTATE"

#-----------------------------
# From here, add a config tree
new "5. Config tree, empty top state, expect default top state and default local state"

CONFIG=$(cat <<EOF
<base-config xmlns="urn:example:lib"><parameter><name>a</name></parameter></base-config>
EOF
)

cat <<EOF > $fstate
EOF

EXPSTATE=$(cat <<EOF
<global-state xmlns="urn:example:lib"><gbds>gbds</gbds><gads xmlns="urn:example:augment">gads</gads></global-state><base-config xmlns="urn:example:lib"><parameter><name>a</name><param-state><lbds>lbds</lbds><lads xmlns="urn:example:augment">lads</lads></param-state></parameter></base-config>
EOF
)

new "Add config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$CONFIG</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

testrun "$CONFIG" "$EXPSTATE"

#-----------------------------

new "6. Config tree and optional tree state, empty top state, expect default top state and default local state"

cat <<EOF > $fstate
<base-config xmlns="urn:example:lib">
   <parameter>
      <name>a</name>
      <param-state>
         <lbos>lbos</lbos>
         <laos xmlns="urn:example:augment">laos</laos>
      </param-state>
   </parameter>
</base-config>
EOF

EXPSTATE=$(cat <<EOF
<global-state xmlns="urn:example:lib"><gbds>gbds</gbds><gads xmlns="urn:example:augment">gads</gads></global-state><base-config xmlns="urn:example:lib"><parameter><name>a</name><param-state><lbds>lbds</lbds><lbos>lbos</lbos><lads xmlns="urn:example:augment">lads</lads><laos xmlns="urn:example:augment">laos</laos></param-state></parameter></base-config>
EOF
)

testrun "$CONFIG" "$EXPSTATE"

#-----------------------------

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
