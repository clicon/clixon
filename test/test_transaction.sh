#!/bin/bash
# Transaction functionality
# The test uses a backend that logs to a file and a netconf client to push
# changes. The main example backend plugin logs to the file, and the test
# verifies the logs.
# The yang is a list with three members, so that you can do add/delete/change
# in a single go.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/trans.yang
flog=$dir/backend.log
touch $flog

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
        description "change this";
        type int32;
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
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
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
    new "Check $s in log"
    t=$(grep "$s" $flog)
    if [ -z "$t" ]; then
	echo -e "\e[31m\nError in Test$testnr [$testname]:"
	if [ $# -gt 0 ]; then 
	    echo "Not found in log"
	    echo
	fi
	echo -e "\e[0m"
	exit -1
    fi
}

new "test params: -f $cfg -l f$flog -- -t"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s init -f $cfg -l f$flog -- -t"
    start_backend -s init -f $cfg -l f$flog -- -t  # -t means transaction logging
    new "waiting"
    sleep $RCWAIT
fi

new "netconf base config (0) a,b,c"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><y><a>0</a><b>0</b><c>0</c></y></x></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf commit base"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'
#Ignore

new "netconf mixed change: change b, del c, add d"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><y><a>0</a><b>42</b><d>0</d></y></x></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf commit change"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

# Check complete transaction 2:
for op in begin validate complete commit; do
    checklog "transaction_log 2 $op add: <d>0</d>"
    checklog "transaction_log 2 $op change: <b>0</b><b>42</b>"
done
# End is special
checklog "transaction_log 2 end add: <d>0</d>"
checklog "transaction_log 2 end change: <b>42</b>"

new "netconf config (1) end-points a,d "
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><y><a>1</a><d>1</d></y></x></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf commit base"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf insert b,c between end-points"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><y><a>1</a><b>1</b><c>1</c></y></x></config></edit-config></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf commit base"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

checklog "transaction_log 4 validate add: <b>1</b><c>1</c>"

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
