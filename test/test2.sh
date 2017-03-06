#!/bin/sh
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
sudo clixon_backend -If $clixon_cf -x 0 # -x 1 with xmldb proxy
if [ $? -ne 0 ]; then
    err
fi
new "netconf show config"
expecteof "clixon_netconf -qf $clixon_cf" "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "<rpc-reply><data></data></rpc-reply>]]>]]>"

new "netconf lock"
expecteof "clixon_netconf -qf $clixon_cf" "<rpc><lock><target><candidate/></target></lock></rpc>]]>]]>" "<rpc-reply><ok/></rpc-reply>]]>]]>"

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

