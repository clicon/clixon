#!/usr/bin/env bash
# Transaction functionality
# The test uses two backend plugins (main and nacm) that logs to a file and a
# netconf client to push operation. The tests then look at the log.
# The test assumes the two plugins recognize the -- -t argument which includes
# that one of them fails at validation at one point
# The tests are as follows (first five only callbacks per se; then data vector tests)
# 1. Validate-only transaction
# 2. Commit transaction
# 3. Validate system-error (invalid type detected by system)
# 4. Validate user-error (invalidation by user callback)
# 5. Commit user-error (invalidation by user callback)
# -- to here only basic callback tests (that they occur). Below transaction data
# 6. Detailed transaction vector add/del/change tests
# For the last test, the yang is a list with three members, so that you can do
# add/delete/change in a single go.
# The user-error uses a trick feature in the example nacm plugin which is started
# with an "error-trigger" xpath which triggers an error. This also toggles between
# validation and commit errors

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/trans.yang
flog=$dir/backend.log
touch $flog

# Used as a trigger for user-validittion errors, eg <a>$errnr</a> = <a>42</a> is invalid
errnr=42

cat <<EOF > $fyang
module trans{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   container x {
    list y {
      key "a";
      leaf a {
        type int32;
      }
      leaf b {
        description "change this (also use to check invalid)";
        type int32{
          range "0..100";
        }
      }
      leaf c {
        description "del this";
        type int32;
      }
      leaf d {
        description "add this";
        type int32;
      }
    }
    choice csame {
        leaf first {
          type boolean;
        }
        leaf second {
          type boolean;
        }
      }
  }
}
EOF

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Check statements in log
# arg1: a statement to look for
# arg2: expected line number
function checklog(){
    s=$1 # statement
    l0=$2 # linenr
    new "Check $s in log"
#    echo "grep \"transaction_log $s line:$l0\"  $flog"
    t=$(grep -n "transaction_log $s" $flog)
    if [ -z "$t" ]; then
	echo -e "\e[31m\nError in Test$testnr [$testname]:"
	if [ $# -gt 0 ]; then 
	    echo "Not found \"$s\" on line $l0"
	    echo
	fi
	echo -e "\e[0m"
	exit -1
    fi
    l1=$(echo "$t" | awk -F ":" '{print $1}')
    if [ $l1 -ne $l0 ]; then
	echo -e "\e[31m\nError in Test$testnr [$testname]:"
	if [ $# -gt 0 ]; then 
	    echo "Expected match on line $l0, found on $l1"
	    echo
	fi
	echo -e "\e[0m"
	exit -1
    fi
}

new "test params: -f $cfg -l f$flog -- -t -v /x/y[a=$errnr]" # Fail on this
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s init -f $cfg -l f$flog -- -t -v /x/y[a=$errnr]"
    start_backend -s init -f $cfg -l f$flog -- -t -v "/x/y[a='$errnr']" # -t means transaction logging
fi

new "wait backend"
wait_backend

let nr=0

new "Basic transaction to add top-level x"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$nr</a></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Commit base"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

let line=14 # Skipping basic transaction

# 1. validate(-only) transaction
let nr++
let line
new "1. Validate-only transaction"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$nr</a></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Validate-only validate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

xml="<y><a>$nr</a></y>"
for op in begin validate complete end; do
    checklog "$nr main_$op add: $xml" $line
    let line++
    checklog "$nr nacm_$op add: $xml" $line
    let line++
done

new "Validate-only discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# 2. Commit transaction
let nr++
new "2. Commit transaction config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$nr</a></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Commit transaction: commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

xml="<y><a>$nr</a></y>"
for op in begin validate complete commit commit_done end; do
    checklog "$nr main_$op add: $xml" $line
    let line++
    checklog "$nr nacm_$op add: $xml" $line
    let line++
done

# 3. Validate only system-error (invalid type detected by system)
let nr++
new "3. Validate system-error config (9999 not in range)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$nr</a><b>9999</b></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Validate system-error validate (should fail)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>b</bad-element></error-info><error-severity>error</error-severity><error-message>Number 9999 out of range: 0 - 100</error-message></rpc-error></rpc-reply>"

new "Validate system-error discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

for op in begin abort; do
    checklog "$nr main_$op add: <y><a>$nr</a><b>9999</b></y>" $line
    let line++
    checklog "$nr nacm_$op add: <y><a>$nr</a><b>9999</b></y>" $line
    let line++
done

# 4. Validate only user-error (invalidation by user callback)
let nr++
new "4. Validate user-error config ($errnr is invalid)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$errnr</a></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Validate user-error validate (should fail)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>User error</error-message></rpc-error></rpc-reply>"

new "Validate user-error discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

for op in begin validate; do
    checklog "$nr main_$op add: <y><a>$errnr</a></y>" $line
    let line++
    checklog "$nr nacm_$op add: <y><a>$errnr</a></y>" $line
    let line++
done
let line++ # error message
for op in abort; do
    checklog "$nr main_$op add: <y><a>$errnr</a></y>" $line
    let line++
    checklog "$nr nacm_$op add: <y><a>$errnr</a></y>" $line
    let line++
done

# 5. Commit user-error (invalidation by user callback)
# XXX Note Validate-only user-error must immediately preceede this due to toggling
# in nacm/transaction example test module
let nr++
new "5. Commit user-error ($errnr is invalid)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$errnr</a></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Commit user-error commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>User error</error-message></rpc-error></rpc-reply>"

new "Commit user-error discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

for op in begin validate complete commit ; do
    checklog "$nr main_$op add: <y><a>$errnr</a></y>" $line
    let line++
    checklog "$nr nacm_$op add: <y><a>$errnr</a></y>" $line
    let line++
done

let line++ # error message
checklog "$nr main_revert add: <y><a>$errnr</a></y>" $line
let line++
for op in abort; do
    checklog "$nr main_$op add: <y><a>$errnr</a></y>" $line
    let line++
    checklog "$nr nacm_$op add: <y><a>$errnr</a></y>" $line
    let line++
done

# 6. Detailed transaction vector add/del/change tests
let nr++
let base=nr
new "Add base <a>$base entry"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$base</a><b>0</b><c>0</c></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit base"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
#Ignore
let line+=12

let nr++
new "6. netconf mixed change: change b, del c, add d"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$base</a><b>42</b><d>0</d></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit change"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Check complete transaction $nr:
for op in begin validate complete commit commit_done; do
    checklog "$nr main_$op add: <d>0</d>" $line
    let line++
    checklog "$nr main_$op change: <b>0</b><b>42</b>" $line
    let line++
    checklog "$nr nacm_$op add: <d>0</d>" $line
    let line++
    checklog "$nr nacm_$op change: <b>0</b><b>42</b>" $line
    let line++
done

# End is special because change does not have old element
checklog "$nr main_end add: <d>0</d>" $line
let line++
# This check does not work if  MOVE_TRANS_END is set
checklog "$nr main_end change: <b>42</b>" $line
let line+=3 # skip nacm

let nr++
let base=nr
new "Add base <a>$base entry"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$base</a><d>1</d></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit base"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
let line+=12

# Variant check that only b,c
let nr++
new "7. netconf insert b,c between end-points"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$base</a><b>1</b><c>1</c></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit base"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# check complete
for op in begin validate complete commit commit_done end; do
    checklog "$nr main_$op add: <b>1</b><c>1</c>" $line
    let line++
    checklog "$nr nacm_$op add: <b>1</b><c>1</c>" $line
    let line++
done

# Variant check that only b,c

new "8. Set first choice"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><first>true</first></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit same"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Set second choice"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><second>true</second></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# choice chanmge with same value did not show up in log
new "netconf commit second"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
let nr++
let nr++

let line+=12
# check complete
for op in begin validate complete commit commit_done; do
    checklog "$nr main_$op change: <first>true</first><second>true</second>" $line
    let line++
    checklog "$nr nacm_$op change: <first>true</first><second>true</second>" $line
    let line++
done

# End is special because change does not have old element
checklog "$nr main_end change: <second>true</second>" $line
let line++
# This check does not work if  MOVE_TRANS_END is set
checklog "$nr nacm_end change: <second>true</second>" $line
let line++
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

unset nr

new "endtest"
endtest
