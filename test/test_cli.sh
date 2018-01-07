#!/bin/bash

# Test1: backend and cli basic functionality
# Start backend server
# Add an ethernet interface and an address
# Show configuration
# Validate without a mandatory type
# Set the mandatory type
# Commit

# include err() and new() functions and creates $dir
. ./lib.sh
cfg=$dir/conf_yang.xml

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/routing/yang</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/routing/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/routing/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>routing</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/routing/routing.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/routing/routing.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/routing</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

# For memcheck
#clixon_cli="valgrind --leak-check=full --show-leak-kinds=all clixon_cli"
clixon_cli=clixon_cli

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err
fi
new "start backend -s init -f $cfg"
sudo clixon_backend -s init -f $cfg 
if [ $? -ne 0 ]; then
    err
fi
new "cli tests"

new "cli configure top"
expectfn "$clixon_cli -1 -f $cfg set interfaces" "^$"

new "cli show configuration top (no presence)"
expectfn "$clixon_cli -1 -f $cfg show conf cli" "^$"

new "cli configure delete top"
expectfn "$clixon_cli -1 -f $cfg delete interfaces" "^$"

new "cli show configuration delete top"
expectfn "$clixon_cli -1 -f $cfg show conf cli" "^$"

new "cli configure"
expectfn "$clixon_cli -1 -f $cfg set interfaces interface eth/0/0" "^$"

new "cli show configuration"
expectfn "$clixon_cli -1 -f $cfg show conf cli" "^interfaces interface name eth/0/0" "interfaces interface enabled true$"

new "cli failed validate"
expectfn "$clixon_cli -1 -f $cfg -l o validate" "Missing mandatory variable"

new "cli configure more"
expectfn "$clixon_cli -1 -f $cfg set interfaces interface eth/0/0 ipv4 address 1.2.3.4 prefix-length 24" "^$"
expectfn "$clixon_cli -1 -f $cfg set interfaces interface eth/0/0 description mydesc" "^$"
expectfn "$clixon_cli -1 -f $cfg set interfaces interface eth/0/0 type bgp" "^$"

new "cli show xpath description"
expectfn "$clixon_cli -1 -f $cfg -l o show xpath /interfaces/interface/description" "<description>mydesc</description>"

new "cli delete description"
expectfn "$clixon_cli -1 -f $cfg -l o delete interfaces interface eth/0/0 description mydesc"

new "cli show xpath no description"
expectfn "$clixon_cli -1 -f $cfg -l o show xpath /interfaces/interface/description" "^$"

new "cli copy interface"
expectfn "$clixon_cli -1 -f $cfg copy interface eth/0/0 to eth99" "^$"

new "cli success validate"
expectfn "$clixon_cli -1 -f $cfg -l o validate" "^$"

new "cli commit"
expectfn "$clixon_cli -1 -f $cfg -l o commit" "^$"

new "cli save"
expectfn "$clixon_cli -1 -f $cfg -l o save /tmp/foo" "^$"

new "cli delete all"
expectfn "$clixon_cli -1 -f $cfg -l o delete all" "^$"

new "cli load"
expectfn "$clixon_cli -1 -f $cfg -l o load /tmp/foo" "^$"

new "cli check load"
expectfn "$clixon_cli -1 -f $cfg -l o show conf cli" "^interfaces interface name eth/0/0" "interfaces interface enabled true$"

new "cli debug"
expectfn "$clixon_cli -1 -f $cfg -l o debug level 1" "^$"
# How to test this?
expectfn "$clixon_cli -1 -f $cfg -l o debug level 0" "^$"

new "cli rpc"
expectfn "$clixon_cli -1 -f $cfg -l o rpc ipv4" "^<rpc-reply>"

new "Kill backend"
# Check if still alive
pid=`pgrep clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
