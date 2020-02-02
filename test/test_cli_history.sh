#!/usr/bin/env bash
# Basic CLI history test

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
histfile=$dir/histfile

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_HIST_FILE>$histfile</CLICON_CLI_HIST_FILE>
  <CLICON_CLI_HIST_SIZE>10</CLICON_CLI_HIST_SIZE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $histfile
first line
EOF

# NOTE Backend is not really used here
new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg

    new "waiting"
    wait_backend
fi

new "cli read and add entry to existing history"
expecteof "$clixon_cli -f $cfg" 0 "example 42" "data"

new "Check histfile exists"
if [ ! -f $histfile ]; then
    err "$histfile" "not found"
fi

new "Check histfile has two entries"
nr=$(cat $histfile | wc -l)
if [ $nr -ne 2 ]; then
    err "2" "$nr"
fi

new "Check histfile contains first line"
nr=$(grep -c "example 42" $histfile)
if [ $nr -ne 1 ]; then
    err "Contains: example 42" "$nr"
fi

new "Check histfile contains example 42"
nr=$(grep -c "example 42" $histfile)
if [ $nr -ne 1 ]; then
    err "1" "$nr"
fi

new "cli add entry and create newhist file"
expecteof "$clixon_cli -f $cfg -o CLICON_CLI_HIST_FILE=$dir/newhist" 0 "example 43" "data"

new "Check newhist exists"
if [ ! -f $dir/newhist ]; then
    err "$dir/newhist" "not found"
fi

new "check it contains example 43"
nr=$(grep -c "example 43" $dir/newhist)
if [ $nr -ne 1 ]; then
    err "1" "$nr"
fi

# Add a long (128 chars) string and see it survives
str128="1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567"
new "cli add long line"
expecteof "$clixon_cli -f $cfg" 0 "$str128" "" 2> /dev/null # ignore error output

new "Check histfile contains long string"
nr=$(grep -c "$str128" $histfile)
if [ $nr -ne 1 ]; then
    err "1" "$nr"
fi

new "cli load arrow-up save -> create two copies of long string"
expecteof "$clixon_cli -f $cfg" 0 "q" "" 
expecteof "$clixon_cli -f $cfg" 0 "" "" 2> /dev/null

new "Check histfile contains two copies of long string"
nr=$(grep -c "$str128" $histfile)
if [ $nr -ne 2 ]; then
    err "2" "$nr"
fi

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

unset nr
rm -rf $dir
