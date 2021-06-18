#!/usr/bin/env bash
# Transaction functionality: restart single plugin and observe that only that plugin
# gets callbacks
# The test uses two backend plugins (main and nacm) that logs.
# nacm is then restarted, not main

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

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
   /* Generic config data */
   container table{
      list parameter{
         key name;
	 leaf name{
	    type string;
	 }
	 leaf value{
	    type string;
	 }
      }
   }
}
EOF

cat <<EOF > $cfg
<clixon-config  $CONFNS>
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

new "test params: -f $cfg -l f$flog -- -t" # Fail on this
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s init -f $cfg -l f$flog -- -t /foo"
    start_backend -s init -f $cfg -l f$flog -- -t /foo # -t means transaction logging (foo is dummy)
fi

new "wait backend"
wait_backend

let nr=0

new "Basic transaction to add top-level x"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><table xmlns='urn:example:clixon'><parameter><name>$nr</name></parameter></table></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Commit base"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

let line=13 # Skipping basic transaction. Sanity check, find one last transaction
xml="<table xmlns=\"urn:example:clixon\"><parameter><name>0</name></parameter></table>"
checklog "$nr nacm_end add: $xml" $line

new "Send restart nacm plugin"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><restart-plugin $LIBNS><plugin>example_backend_nacm</plugin></restart-plugin></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

# Now analyze log:
# all transactions come from nacm plugin only.
let nr++
let line=14

for op in begin validate complete commit commit_done end; do
    checklog "$nr nacm_$op add: $xml" $line
    let line++
done

# Negative test: restart a plugin that does not exist
new "Send restart to nonexistatn plugin expect fail"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><restart-plugin $LIBNS><plugin>xxx</plugin></restart-plugin></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>plugin</bad-element></error-info><error-severity>error</error-severity><error-message>No such plugin</error-message></rpc-error></rpc-reply>]]>]]>$"

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
