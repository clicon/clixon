#!/usr/bin/env bash
# Netconf confirm commit capability
# See RFC 6241 Section 8.4 and RFC 8040 Section 1.4
# TODO:
# - privileges drop
# - lock check
# Notes:
# 1. May tests without "new" which makes it difficult to debug
# 2. Sleeps are difficult when running valgrind tests when startup times (eg netconf) increase
# Occasionally fails (non-determinisitic) when asserting running, see marked TIMEOUT? below

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
tmp=$dir/tmp.x
fyang=$dir/clixon-example.yang

# Backend user for priv drop, otherwise root
USER=${BUSER}

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>ietf-netconf:confirmed-commit</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_BACKEND_USER>$USER</CLICON_BACKEND_USER>
  <CLICON_BACKEND_PRIVILEGES>drop_perm</CLICON_BACKEND_PRIVILEGES>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;

    /* Generic config data */
    container table{
        list parameter{
            key name;
            leaf name{
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
  new "commit $1"
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
  new "edit-config $1 $2"
  rpc "<edit-config><target><$TARGET/></target><config>$CONFIG</config></edit-config>" "<ok/>"
}

function assert_config_equals() {
  TARGET="$1"
  EXPECTED="$2"
  new "assert_config_equals $TARGET"
  rpc "<get-config><source><$TARGET/></source></get-config>" "$(data "$EXPECTED")"
}

# delete all
function reset() {
  new "reset"
  rpc "<edit-config><target><candidate/></target><default-operation>none</default-operation><config operation=\"delete\"/></edit-config>" "<ok/>"
  commit
  assert_config_equals "candidate" ""
  assert_config_equals "running" ""
}

CANDIDATE_PATH="/usr/local/var/$APPNAME/candidate_db"
RUNNING_PATH="/usr/local/var/$APPNAME/running_db"
ROLLBACK_PATH="/usr/local/var/$APPNAME/rollback_db"
FAILSAFE_PATH="/usr/local/var/$APPNAME/failsafe_db"


CONFIGB="<table xmlns=\"urn:example:clixon\"><parameter><name>eth0</name></parameter></table>"
CONFIGC="<table xmlns=\"urn:example:clixon\"><parameter><name>eth1</name></parameter></table>"
CONFIGCONLY="<parameter xmlns=\"urn:example:clixon\"><name>eth1</name></parameter>" # restcpnf
CONFIGBPLUSC="<table xmlns=\"urn:example:clixon\"><parameter><name>eth0</name></parameter><parameter><name>eth1</name></parameter></table>"
FAILSAFE_CFG="<table xmlns=\"urn:example:clixon\"><parameter><name>eth99</name></parameter></table>"

new "test params: -f $cfg"

# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    stop_backend -f $cfg

    new "start backend  -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "1. Hello check confirm-commit capability"
expecteof "$clixon_netconf -f $cfg" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTONLY><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>" "<capability>urn:ietf:params:netconf:capability:confirmed-commit:1.1</capability>" '^$'

################################################################################
new "2. netconf ephemeral confirmed-commit rolls back after disconnect"
reset
edit_config "candidate" "$CONFIGB"
assert_config_equals "candidate" "$CONFIGB"
commit "<confirmed/><confirm-timeout>30</confirm-timeout>"
assert_config_equals "running" ""

################################################################################

new "3.netconf persistent confirmed-commit"
reset
edit_config "candidate" "$CONFIGB"
commit "<confirmed/><persist>a</persist>"
assert_config_equals "running" "$CONFIGB"
edit_config "candidate" "$CONFIGC"
commit "<confirmed/><persist>ab</persist><persist-id>a</persist-id>"
assert_config_equals "running" "$CONFIGBPLUSC"

################################################################################

new "4. netconf cancel-commit with invalid persist-id"
rpc "<cancel-commit><persist-id>abc</persist-id></cancel-commit>" "<rpc-error><error-type>application</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>a confirmed-commit with the given persist-id was not found</error-message></rpc-error>"

################################################################################

new "5. netconf cancel-commit with valid persist-id"
rpc "<cancel-commit><persist-id>ab</persist-id></cancel-commit>" "<ok/>"

################################################################################

new "6. netconf persistent confirmed-commit with timeout"
reset
edit_config "candidate" "$CONFIGB"
commit "<confirmed/><confirm-timeout>3</confirm-timeout><persist>abcd</persist>"
assert_config_equals "running" "$CONFIGB"
sleep 3
assert_config_equals "running" ""

################################################################################

new "7. netconf persistent confirmed-commit with reset timeout"
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

################################################################################

new "8. netconf persistent confirming-commit to epehemeral confirmed-commit should rollback"
reset
edit_config "candidate" "$CONFIGB"
commit "<confirmed/><persist/><confirm-timeout>10</confirm-timeout>"
assert_config_equals "running" "$CONFIGB"
commit "<confirmed/><persist-id/>"
assert_config_equals "running" ""

################################################################################

new "9. netconf confirming-commit for persistent confirmed-commit with empty persist value"
reset
edit_config "candidate" "$CONFIGB"
commit "<confirmed/><persist/><confirm-timeout>10</confirm-timeout>"
assert_config_equals "running" "$CONFIGB"
commit "<persist-id/>"
assert_config_equals "running" "$CONFIGB"

################################################################################
# TODO reconsider logic around presence/absence of rollback_db as a signal as dropping permissions may impact ability
# to unlink and/or create that file. see clixon_datastore.c#xmldb_delete() and backend_startup.c#startup_mode_startup()

new "10. backend loads rollback if present at startup"
reset
edit_config "candidate" "$CONFIGB"
commit ""
edit_config "candidate" "$CONFIGC"
commit "<persist>abcdefg</persist><confirmed/>"
assert_config_equals "running" "$CONFIGBPLUSC"

new "kill old backend"
stop_backend -f $cfg                                            # kill backend and restart

new "Check $ROLLBACK_PATH"
[ -f "$ROLLBACK_PATH" ] || err "rollback_db doesn't exist!"     # assert rollback_db exists

new "start backend -s running -f $cfg"
start_backend -s running -f $cfg

new "wait backend"
wait_backend

assert_config_equals "running" "$CONFIGB"

new "Check $ROLLBACK_PATH removed"
[ -f "ROLLBACK_PATH" ] && err "rollback_db still exists!"       # assert rollback_db doesn't exist

new "kill old backend"
stop_backend -f $cfg

new "start backend -s init -f $cfg"
start_backend -s init -f $cfg

################################################################################
new "11. backend loads failsafe at startup if rollback present but cannot be loaded"

new "wait backend"
wait_backend

reset

sudo tee "$FAILSAFE_PATH" > /dev/null << EOF                    # create a failsafe database
<config>$FAILSAFE_CFG</config>
EOF
edit_config "candidate" "$CONFIGC"

commit "<persist>foobar</persist><confirmed/>"

assert_config_equals "running" "$CONFIGC"

new "kill old backend"
stop_backend -f $cfg                                            # kill the backend

sudo rm $ROLLBACK_PATH                                          # modify rollback_db so it won't commit successfully

sudo tee "$ROLLBACK_PATH" > /dev/null << EOF
<foo>
  <bar>
    <baz/>
    </bar>
</foo>
EOF

new "start backend -s running -f $cfg"
start_backend -s running -f $cfg

new "wait backend"
wait_backend

assert_config_equals "running" "$FAILSAFE_CFG"

new "kill old backend"
stop_backend -f $cfg

new "start backend -s init -f $cfg"
start_backend -s init -f $cfg -lf/tmp/clixon.log -D1

new "wait backend"
wait_backend

################################################################################

new "12. ephemeral confirmed-commit survives unrelated ephemeral session disconnect"
reset
edit_config "candidate" "$CONFIGB"
assert_config_equals "candidate" "$CONFIGB"
# start a new ephemeral confirmed commit, but keep the confirmed-commit session alive (need to put it in the background)
# use HELLONO11 which uses older EOM framing
sleep 60 |  cat <(echo "$HELLONO11<rpc $DEFAULTNS><commit><confirmed/><confirm-timeout>60</confirm-timeout></commit></rpc>]]>]]>") -| $clixon_netconf -qf $cfg  >> /dev/null &
PIDS=($(jobs -l % | cut -c 6- | awk '{print $1}'))
sleep 1 # TIMEOUT?
assert_config_equals "running" "$CONFIGB"                       # assert config twice to prove it survives disconnect
assert_config_equals "running" "$CONFIGB"                       # of ephemeral sessions

new "soft kill ${PIDS[0]}"
kill ${PIDS[0]}                   # kill the while loop above to close STDIN on 1st

################################################################################

new "13. cli ephemeral confirmed-commit rolls back after disconnect"
reset

tmppipe=$(mktemp -u)
mkfifo -m 600 "$tmppipe"

cat << EOF | $clixon_cli -f $cfg >> /dev/null &
set table parameter eth0
commit confirmed 60
shell echo >> $tmppipe
shell cat $tmppipe
quit
EOF

cat $tmppipe >> /dev/null
assert_config_equals "running" "$CONFIGB"
echo >> $tmppipe
sleep 1
assert_config_equals "running" ""
rm $tmppipe

################################################################################

new "14. cli persistent confirmed-commit"
reset

cat << EOF | $clixon_cli -f $cfg >> /dev/null
set table parameter eth0
commit confirmed persist a
quit
EOF

assert_config_equals "running" "$CONFIGB"

cat << EOF | $clixon_cli -f $cfg >> /dev/null
set table parameter eth1
commit persist-id a confirmed persist ab
quit
EOF
assert_config_equals "running" "$CONFIGBPLUSC"

################################################################################

new "15. cli cancel-commit with invalid persist-id"
expectpart "$($clixon_cli -lo -1 -f $cfg commit persist-id abc cancel)" 255 "a confirmed-commit with the given persist-id was not found"

################################################################################

new "16. cli cancel-commit with valid persist-id"
expectpart "$($clixon_cli -lo -1 -f $cfg commit persist-id ab cancel)" 0 "^$"
assert_config_equals "running" ""

################################################################################

new "17. cli cancel-commit with no confirmed-commit in progress"
expectpart "$($clixon_cli -lo -1 -f $cfg commit persist-id ab cancel)" 255 "no confirmed-commit is in progress"

################################################################################

new "18. cli persistent confirmed-commit with timeout"
reset
cat << EOF | $clixon_cli -f $cfg >> /dev/null
set table parameter eth0
commit confirmed persist abcd 3
EOF
assert_config_equals "running" "$CONFIGB"
sleep 3
assert_config_equals "running" ""

################################################################################

new "19. cli persistent confirmed-commit with reset timeout"
reset
cat << EOF | $clixon_cli -f $cfg >> /dev/null
set table parameter eth0
commit confirmed persist abcd 5
EOF

assert_config_equals "running" "$CONFIGB"
cat << EOF | $clixon_cli -f $cfg >> /dev/null
set table parameter eth1
commit persist-id abcd confirmed persist abcdef 10
EOF

sleep 6
assert_config_equals "running" "$CONFIGBPLUSC"
# now sleep long enough for rollback to happen; get config, assert == A
sleep 5
assert_config_equals "running" ""

# TODO test restconf receives "409 conflict" when there is a persistent confirmed-commit active
# TODO test restconf causes confirming-commit for ephemeral confirmed-commit
if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

new "restconf as confirmed commit"
reset
edit_config "candidate" "$CONFIGB"
assert_config_equals "candidate" "$CONFIGB"
# use HELLONO11 which uses older EOM framing
sleep 60 |  cat <(echo "$HELLONO11<rpc $DEFAULTNS><commit><confirmed/><confirm-timeout>60</confirm-timeout></commit></rpc>]]>]]><rpc $DEFAULTNS><commit></commit></rpc>]]>]]>") -| $clixon_netconf -qf $cfg  >> /dev/null &
PIDS=($(jobs -l % | cut -c 6- | awk '{print $1}'))
sleep 1 # TIMEOUT?
assert_config_equals "running" "$CONFIGB"                       # assert config twice to prove it surives disconnect

new "restconf POST"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" -d "$CONFIGCONLY" $RCPROTO://localhost/restconf/data/clixon-example:table)" 0 "HTTP/$HVER 201" "location:"

assert_config_equals "running" "$CONFIGBPLUSC"

new "soft kill ${PIDS[0]}"
kill ${PIDS[0]}                   # kill the while loop above to close STDIN on 1st

assert_config_equals "running" "$CONFIGBPLUSC"

################################################################################

new "20. restconf persistid expect fail"
reset
edit_config "candidate" "$CONFIGB"
commit "<confirmed/><persist>a</persist>"
assert_config_equals "running" "$CONFIGB"

new "restconf POST"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" -d "$CONFIGCONLY" $RCPROTO://localhost/restconf/data/clixon-example:table)" 0 # "HTTP/$HVER 409"

assert_config_equals "running" "$CONFIGB"

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf 
fi

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u ${USER} -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
