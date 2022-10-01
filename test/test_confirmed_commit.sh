#!/usr/bin/env bash
# Basic Netconf functionality
# Mainly default/null prefix, but also xx: prefix
# XXX: could add tests for dual prefixes xx and xy with doppelganger names, ie xy:filter that is
# syntactic correct but wrong

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
tmp=$dir/tmp.x
fyang=$dir/clixon-example.yang

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-netconf:confirmed-commit</CLICON_FEATURE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_NETCONF_MESSAGE_ID_OPTIONAL>false</CLICON_NETCONF_MESSAGE_ID_OPTIONAL>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   import ietf-interfaces {
	prefix if;
   }
   import ietf-ip {
	prefix ip;
   }
   /* Example interface type for tests, local callbacks, etc */
   identity eth {
	base if:interface-type;
   }
    /* Generic config data */
    container table{
	list parameter{
	    key name;
	    leaf name{
		type string;
	    }
	}
    }
   /* State data (not config) for the example application*/
   container state {
	config false;
	description "state data for the example application (must be here for example get operation)";
	leaf-list op {
            type string;
	}
   }
   augment "/if:interfaces/if:interface" {
	container my-status {
	    config false;
	    description "For testing augment+state";
	    leaf int {
		type int32;
	    }
	    leaf str {
		type string;
	    }
	}
    }
    rpc client-rpc {
	description "Example local client-side RPC that is processed by the
                     the netconf/restconf and not sent to the backend.
                     This is a clixon implementation detail: some rpc:s
                     are better processed by the client for API or perf reasons";
	input {
	    leaf x {
		type string;
	    }
	}
	output {
	    leaf x {
		type string;
	    }
	}
    }
    rpc empty {
	description "Smallest possible RPC with no input or output sections";
    }
    rpc example {
	description "Some example input/output for testing RFC7950 7.14.
                     RPC simply echoes the input for debugging.";
	input {
	    leaf x {
		description
         	    "If a leaf in the input tree has a 'mandatory' statement with
                   the value 'true', the leaf MUST be present in an RPC invocation.";
		type string;
		mandatory true;
	    }
	    leaf y {
		description
		    "If a leaf in the input tree has a 'mandatory' statement with the
                  value 'true', the leaf MUST be present in an RPC invocation.";
		type string;
		default "42";
	    }
	}
	output {
	    leaf x {
		type string;
	    }
	    leaf y {
		type string;
	    }
	}
    }

}
EOF

function data() {
  if [[ "$1" == "" ]]
  then
    echo "<data/>"
  else
    echo "<data>$1</data>"
  fi
}

# Pipe stdin to command and also do chunked framing (netconf 1.1)
# Arguments:
# - Command
# - expected command return value (0 if OK)
# - stdin input1  This is NOT encoded, eg preamble/hello
# - stdin input2  This gets chunked encoding
# - expect1 stdout outcome, can be partial and contain regexps
# - expect2 stdout outcome This gets chunked encoding, must be complete netconf message
# Use this if you want regex eg  ^foo$

function rpc() {
  expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS>$1</rpc>" "" "<rpc-reply $DEFAULTNS>$2</rpc-reply>"
}

function commit() {
  if [[ "$1" == "" ]]
  then
    rpc "<commit/>" "<ok/>"
  else
    rpc "<commit>$1</commit>" "<ok/>"
  fi
}

function edit_config() {
  TARGET="$1"
  CONFIG="$2"
  rpc "<edit-config><target><$TARGET/></target><config>$CONFIG</config></edit-config>" "<ok/>"
}

function assert_config_equals() {
  TARGET="$1"
  EXPECTED="$2"
  rpc "<get-config><source><$TARGET/></source></get-config>" "$(data "$EXPECTED")"
}

function reset() {
  rpc "<edit-config><target><candidate/></target><default-operation>none</default-operation><config operation=\"delete\"/></edit-config>" "<ok/>"
  commit
  assert_config_equals "candidate" ""
  assert_config_equals "running" ""
}

CANDIDATE_PATH="/usr/local/var/$APPNAME/candidate_db"
RUNNING_PATH="/usr/local/var/$APPNAME/running_db"
ROLLBACK_PATH="/usr/local/var/$APPNAME/rollback_db"
FAILSAFE_PATH="/usr/local/var/$APPNAME/failsafe_db"

CONFIGB="<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth0</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>"
CONFIGC="<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>"
CONFIGBPLUSC="<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth0</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>eth1</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>"
FAILSAFE_CFG="<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface><name>eth99</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>"

# TODO this test suite is somewhat brittle as it relies on the presence of the example configuration that one gets with
# make install-example in the Clixon distribution.  It would be better if the dependencies were entirely self contained.

new "test params: -f $cfg -- -s"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s init -f $cfg -- -s"
    start_backend -s init -f $cfg -- -s
fi

new "wait backend"
wait_backend

new "netconf ephemeral confirmed-commit rolls back after disconnect"
reset
edit_config "candidate" "$CONFIGB"
assert_config_equals "candidate" "$CONFIGB"
commit "<confirmed/><confirm-timeout>30</confirm-timeout>"
assert_config_equals "running" ""

new "netconf persistent confirmed-commit"
reset
edit_config "candidate" "$CONFIGB"
commit "<confirmed/><persist>a</persist>"
assert_config_equals "running" "$CONFIGB"
edit_config "candidate" "$CONFIGC"
commit "<confirmed/><persist>ab</persist><persist-id>a</persist-id>"
assert_config_equals "running" "$CONFIGBPLUSC"

new "netconf cancel-commit with invalid persist-id"
rpc "<cancel-commit><persist-id>abc</persist-id></cancel-commit>" "<rpc-error><error-type>application</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>a confirmed-commit with the given persist-id was not found</error-message></rpc-error>"

new "netconf cancel-commit with valid persist-id"
rpc "<cancel-commit><persist-id>ab</persist-id></cancel-commit>" "<ok/>"

new "netconf persistent confirmed-commit with timeout"
reset
edit_config "candidate" "$CONFIGB"
commit "<confirmed/><confirm-timeout>2</confirm-timeout><persist>abcd</persist>"
assert_config_equals "running" "$CONFIGB"
sleep 2
assert_config_equals "running" ""

new "netconf persistent confirmed-commit with reset timeout"
reset
edit_config "candidate" "$CONFIGB"
commit "<confirmed/><persist>abcde</persist><confirm-timeout>5</confirm-timeout>"
assert_config_equals "running" "$CONFIGB"
edit_config "candidate" "$CONFIGC"
commit "<confirmed/><persist-id>abcde</persist-id><persist>abcdef</persist><confirm-timeout>10</confirm-timeout>"
# prove the new timeout is active by sleeping longer than first timeout. get config, assert == B+C
sleep 6
assert_config_equals "running" "$CONFIGBPLUSC"
# now sleep long enough for rollback to happen; get config, assert == A
sleep 5
assert_config_equals "running" ""

new "netconf persistent confirming-commit to epehemeral confirmed-commit should rollback"
reset
edit_config "candidate" "$CONFIGB"
commit "<confirmed/><persist/><confirm-timeout>10</confirm-timeout>"
assert_config_equals "running" "$CONFIGB"
commit "<confirmed/><persist-id/>"
assert_config_equals "running" ""

new "netconf confirming-commit for persistent confirmed-commit with empty persist value"
reset
edit_config "candidate" "$CONFIGB"
commit "<confirmed/><persist/><confirm-timeout>10</confirm-timeout>"
assert_config_equals "running" "$CONFIGB"
commit "<persist-id/>"
assert_config_equals "running" "$CONFIGB"

# TODO the next two tests are broken.  The whole idea of presence or absence of rollback_db indicating something might
# need reconsideration. see clixon_datastore.c#xmldb_delete() and backend_startup.c#startup_mode_startup()

new "backend loads rollback if present at startup"
reset
edit_config "candidate" "$CONFIGB"
commit ""
edit_config "candidate" "$CONFIGC"
commit "<persist>abcdefg</persist><confirmed/>"
assert_config_equals "running" "$CONFIGBPLUSC"
stop_backend -f $cfg                                            # kill backend and restart
[ -f "$ROLLBACK_PATH" ] || err "rollback_db doesn't exist!"     # assert rollback_db exists
start_backend -s running -f $cfg -- -s
wait_backend
assert_config_equals "running" "$CONFIGB"
[ -f "ROLLBACK_PATH" ] && err "rollback_db still exists!"       # assert rollback_db doesn't exist

stop_backend -f $cfg
start_backend -s init -f $cfg -- -s

new "backend loads failsafe at startup if rollback present but cannot be loaded"
reset

sudo tee "$FAILSAFE_PATH" > /dev/null << EOF                    # create a failsafe database
<config>$FAILSAFE_CFG</config>
EOF

edit_config "candidate" "$CONFIGC"
commit "<persist>foobar</persist><confirmed/>"
assert_config_equals "running" "$CONFIGC"
stop_backend -f $cfg                                            # kill the backend
sudo rm $ROLLBACK_PATH                                          # modify rollback_db so it won't commit successfully
sudo tee "$ROLLBACK_PATH" > /dev/null << EOF
<foo>
  <bar>
    <baz/>
    </bar>
</foo>
EOF
start_backend -s running -f $cfg -- -s
wait_backend
assert_config_equals "running" "$FAILSAFE_CFG"


# TODO this test is now broken too, but not sure why; suspicion that the initial confirmed-commit session is not kept alive as intended
stop_backend -f $cfg
start_backend -s init -f $cfg -lf/tmp/clixon.log -D1 -- -s
wait_backend
new "ephemeral confirmed-commit survives unrelated ephemeral session disconnect"
reset
edit_config "candidate" "$CONFIGB"
# start a new ephemeral confirmed commit, but keep the confirmed-commit session alive (need to put it in the background)
sleep 60 |  cat <(echo "$DEFAULTHELLO<rpc $DEFAULTNS><commit><confirmed/><confirm-timeout>60</confirm-timeout></commit></rpc>]]>]]>") -| $clixon_netconf -qf $cfg  >> /dev/null &
PIDS=($(jobs -l % | cut -c 6- | awk '{print $1}'))
assert_config_equals "running" "$CONFIGB"                       # assert config twice to prove it surives disconnect
assert_config_equals "running" "$CONFIGB"                       # of ephemeral sessions

kill -9 ${PIDS[0]}                                              # kill the while loop above to close STDIN on 1st
                                                                # ephemeral session and cause rollback
assert_config_equals "running" ""


# TODO test same cli methods as tested for netconf
# TODO test restconf receives "409 conflict" when there is a persistent confirmed-commit active
# TODO test restconf causes confirming-commit for ephemeral confirmed-commit


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

new "endtest"
endtest
