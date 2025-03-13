#!/usr/bin/env bash
# Transaction functionality: Start from startup and ensure 
# first transaction is OK including diff
# See eg https://github.com/clicon/clixon/issues/596

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/trans.yang
flog=$dir/backend.log
touch $flog

# Used as a trigger for user-validation errors, eg <a>$errnr</a> = <a>42</a> is invalid
errnr=42

cat <<EOF > $fyang
module trans{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   container x {
     leaf y {
       type string;
       default "abc";
     }
     leaf z {
       type string;
     }
  }
}
EOF

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Create startup db revision from 2014-05-08 to be upgraded to 2018-02-20
# This is 2014 syntax
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
   <x xmlns="urn:example:clixon">
      <z>efg</z>
   </x>
</${DATASTORE_TOP}>
EOF

# Check statements in log
# arg1: a statement to look for
# arg2: expected line number
function checklog(){
    s=$1 # statement
    l0=$2 # linenr
    new "Check $s in log"
    echo "grep \"transaction_log $s line:$l0\"  $flog"
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
    start_backend -s startup -f $cfg -l f$flog -- -t # -t means transaction logging
fi

new "wait backend"
wait_backend

let line=0 # Skipping basic transaction
let line++

checklog "0 main_begin add: <x xmlns=\"urn:example:clixon\"><y>abc</y><z>efg</z></x>" $line

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
