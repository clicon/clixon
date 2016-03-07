#!/bin/sh

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
sudo clixon_backend -If $clixon_cf -x 0
if [ $? -ne 0 ]; then
    err
fi
new "cli configure"
clifn "clixon_cli -1f $clixon_cf set interfaces interface eth0" ""

new "cli show configuration"
clifn "clixon_cli -1f $clixon_cf show conf cli" "interfaces interface name eth0
interfaces interface enabled true"

new "Kill backend"
# kill backend
sudo clixon_backend -zf $clixon_cf
if [ $? -ne 0 ]; then
    err
fi

