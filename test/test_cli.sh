#!/usr/bin/env bash
# Backend and cli basic functionality
# Start backend server
# Add an ethernet interface and an address
# Show configuration
# Validate without a mandatory type
# Set the mandatory type
# Commit

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend
    
new "cli configure top"
expectpart "$($clixon_cli -1 -f $cfg set interfaces)" 0 "^$"

new "cli show configuration top (no presence)"
expectpart "$($clixon_cli -1 -f $cfg show conf cli)" 0 "^$"

new "cli configure delete top"
expectpart "$($clixon_cli -1 -f $cfg delete interfaces)" 0 "^$"

new "cli show configuration delete top"
expectpart "$($clixon_cli -1 -f $cfg show conf cli)" 0 "^$"

new "cli configure set interfaces"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth/0/0)" 0 "^$"

new "cli show configuration"
expectpart "$($clixon_cli -1 -f $cfg show conf cli)" 0 "^set interfaces interface eth/0/0" "^set interfaces interface eth/0/0 enabled true"

new "cli configure using encoded chars data <&"
# problems in changing to expectpart with escapes
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth/0/0 description "\"foo<&bar\"")" 0 ""

new "cli configure using encoded chars name <&"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface "fddi&<" type ianaift:ethernetCsmacd)" 0 ""

new "cli failed validate"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 255 "Validate failed. Edit and try again or discard changes: application missing-element Mandatory variable of interface in module ietf-interfaces <bad-element>type</bad-element>"

new "cli configure ip addr"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth/0/0 ipv4 address 1.2.3.4 prefix-length 24)" 0 "^$"

new "cli configure ip descr"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth/0/0 description mydesc)" 0 "^$"

new "cli configure ip type"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth/0/0 type ex:eth)" 0 "^$"

new "cli show xpath description"
expectpart "$($clixon_cli -1 -f $cfg -l o show xpath /interfaces/interface/description urn:ietf:params:xml:ns:yang:ietf-interfaces)" 0 "<description>mydesc</description>"

new "cli delete description"
expectpart "$($clixon_cli -1 -f $cfg -l o delete interfaces interface eth/0/0 description mydesc)" 0 ""

new "cli show xpath no description"
expectpart "$($clixon_cli -1 -f $cfg -l o show xpath /interfaces/interface/description urn:ietf:params:xml:ns:yang:ietf-interfaces)" 0 "^$"

new "cli copy interface"
expectpart "$($clixon_cli -1 -f $cfg copy interface eth/0/0 to eth99)" 0 "^$"

new "cli success validate"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 0 "^$"

new "cli compare diff"
expectpart "$($clixon_cli -1 -f $cfg -l o show compare text)" 0 "+                ip 1.2.3.4;"

new "cli start shell"
expectpart "$($clixon_cli -1 -f $cfg -l o shell echo foo)" 0 "foo" 

new "cli commit"
expectpart "$($clixon_cli -1 -f $cfg -l o commit)" 0 "^$"

new "cli save"
expectpart "$($clixon_cli -1 -f $cfg -l o save $dir/foo)" 0 "^$"

new "cli delete all"
expectpart "$($clixon_cli -1 -f $cfg -l o delete all)" 0 "^$"

new "cli load"
expectpart "$($clixon_cli -1 -f $cfg -l o load $dir/foo)" 0 "^$"

new "cli check load"
expectpart "$($clixon_cli -1 -f $cfg -l o show conf cli)" 0 "interfaces interface eth/0/0 ipv4 enabled true"

new "cli debug set"
expectpart "$($clixon_cli -1 -f $cfg -l o debug cli 1)" 0 "^$"

# How to test this?
new "cli debug reset"
expectpart "$($clixon_cli -1 -f $cfg -l o debug cli 0)" 0 "^$"

new "cli rpc"
# We dont know which message-id the cli app uses
expectpart "$($clixon_cli -1 -f $cfg -l o rpc ipv4)" 0 "<rpc-reply $DEFAULTONLY message-id=" "><x xmlns=\"urn:example:clixon\">ipv4</x><y xmlns=\"urn:example:clixon\">42</y></rpc-reply>"

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
