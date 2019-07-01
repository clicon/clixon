#!/bin/bash
# Transaction functionality
# The test uses two backend plugins (main and nacm) that logs to a file and a
# netconf client to push operation. The tests then look at the log.
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

# Which format to use as datastore format internally
: ${format:=xml}

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/trans.yang
flog=$dir/backend.log
touch $flog

# Used as a trigger for user-validittion errors, eg <a>$errnr</a> is invalid
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
  }
}
EOF

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <!--CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP-->
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
</clixon-config>
EOF

# Check statements in log
checklog(){
    s=$1 # statement
    l0=$2 # linenr
    new "Check $s in log"
#    echo "grep \"transaction_log $s\"  $flog"
    t=$(grep -n "transaction_log $s" $flog)
    if [ -z "$t" ]; then
	echo -e "\e[31m\nError in Test$testnr [$testname]:"
	if [ $# -gt 0 ]; then 
	    echo "Not found in log"
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

new "test params: -f $cfg -l f$flog -- -t /x/y[a=$errnr]" # Fail on this
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s init -f $cfg -l f$flog -- -t /x/y[a=$errnr]"
    start_backend -s init -f $cfg -l f$flog -- -t /x/y[a=$errnr] # -t means transaction logging

    new "waiting"
    wait_backend
fi

let nr=0

new "Basic transaction to add top-level x"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$nr</a></y></x></config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Commit base"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

let line=12 # Skipping basic transaction

# 1. validate(-only) transaction
let nr++
let line
new "1. Validate-only transaction"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$nr</a></y></x></config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Validate-only validate"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

xml="<y><a>$nr</a></y>"
for op in begin validate complete end; do
    checklog "$nr main_$op add: $xml" $line
    let line++
    checklog "$nr nacm_$op add: $xml" $line
    let line++
done

new "Validate-only discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# 2. Commit transaction
let nr++
new "2. Commit transaction config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$nr</a></y></x></config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Commit transaction: commit"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

xml="<y><a>$nr</a></y>"
for op in begin validate complete commit end; do
    checklog "$nr main_$op add: $xml" $line
    let line++
    checklog "$nr nacm_$op add: $xml" $line
    let line++
done

# 3. Validate only system-error (invalid type detected by system)
let nr++
new "3. Validate system-error config (9999 not in range)"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$nr</a><b>9999</b></y></x></config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Validate system-error validate (should fail)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>b</bad-element></error-info><error-severity>error</error-severity><error-message>Number 9999 out of range: 0 - 100</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Validate system-error discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

for op in begin abort; do
    checklog "$nr main_$op add: <y><a>$nr</a><b>9999</b></y>" $line
    let line++
    checklog "$nr nacm_$op add: <y><a>$nr</a><b>9999</b></y>" $line
    let line++
done

# 4. Validate only user-error (invalidation by user callback)
let nr++
new "4. Validate user-error config ($errnr is invalid)"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$errnr</a></y></x></config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Validate user-error validate (should fail)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>User error</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Validate user-error discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

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
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$errnr</a></y></x></config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "Commit user-error commit"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>User error</error-message></rpc-error></rpc-reply>]]>]]>$'

new "Commit user-error discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

for op in begin validate complete commit; do
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
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$base</a><b>0</b><c>0</c></y></x></config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf commit base"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'
#Ignore
let line+=10

let nr++
new "6. netconf mixed change: change b, del c, add d"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$base</a><b>42</b><d>0</d></y></x></config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf commit change"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

# Check complete transaction $nr:
for op in begin validate complete commit; do
    checklog "$nr main_$op add: <d>0</d>" $line
    let line++
    checklog "$nr main_$op change: <b>0</b><b>42</b>" $line
    let line++
    checklog "$nr nacm_$op add: <d>0</d>" $line
    let line++
    checklog "$nr nacm_$op change: <b>0</b><b>42</b>" $line
    let line++
done

# End is special because change does not haveold element
checklog "$nr main_end add: <d>0</d>" $line
let line++
checklog "$nr main_end change: <b>42</b>" $line
let line+=3 # skip nacm

let nr++
let base=nr
new "Add base <a>$base entry"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$base</a><d>1</d></y></x></config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf commit base"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'
let line+=10

# Variant check that only b,c
let nr++
new "7. netconf insert b,c between end-points"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config><x xmlns='urn:example:clixon'><y><a>$base</a><b>1</b><c>1</c></y></x></config></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf commit base"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

# check complete
for op in begin validate complete commit end; do
    checklog "$nr main_$op add: <b>1</b><c>1</c>" $line
    let line++
    checklog "$nr nacm_$op add: <b>1</b><c>1</c>" $line
    let line++
done

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

#rm -rf $dir
