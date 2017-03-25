#!/bin/bash
# Test1: backend and cli basic functionality
# Start backend server
# Add an ethernet interface and an address
# Show configuration
# Validate without a mandatory type
# Set the mandatory type
# Commit

# include err() and new() functions
. ./lib.sh

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $clixon_cf
if [ $? -ne 0 ]; then
    err
fi
new "start backend"
# start new backend
sudo clixon_backend -If $clixon_cf 
if [ $? -ne 0 ]; then
    err
fi
new "cli configure"
expectfn "clixon_cli -1f $clixon_cf set interfaces interface eth0" ""

new "cli show configuration"
expectfn "clixon_cli -1f $clixon_cf show conf cli" "^interfaces interface name eth0
interfaces interface enabled true$"

new "cli failed validate"
expectfn "clixon_cli -1f $clixon_cf -l o validate" "Missing mandatory variable"

new "cli configure more"
expectfn "clixon_cli -1f $clixon_cf set interfaces interface eth0 ipv4 address 1.2.3.4 prefix-length 24" ""
expectfn "clixon_cli -1f $clixon_cf set interfaces interface eth0 type bgp" ""

new "cli commit"
expectfn "clixon_cli -1f $clixon_cf -l o commit" ""

new "cli save"
expectfn "clixon_cli -1f $clixon_cf -l o save /tmp/foo" ""

new "cli delete all"
expectfn "clixon_cli -1f $clixon_cf -l o delete all" ""

new "cli load"
expectfn "clixon_cli -1f $clixon_cf -l o load /tmp/foo" ""

new "cli check load"
expectfn "clixon_cli -1f $clixon_cf -l o show conf cli" "^interfaces interface name eth0
interfaces interface enabled true$"

new "cli debug"
expectfn "clixon_cli -1f $clixon_cf -l o debug level 1" ""

new "cli downcall"
expectfn "clixon_cli -1f $clixon_cf -l o downcall \"This is a test =====\"" "^\"This is a test =====\"$"

new "Kill backend"
# Check if still alive
pid=`pgrep clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -zf $clixon_cf
if [ $? -ne 0 ]; then
    err "kill backend"
fi

