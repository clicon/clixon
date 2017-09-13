#!/bin/bash
# Test2: backend and netconf basic functionality

number=10000

# include err() and new() functions
. ./lib.sh

# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
clixon_netconf=clixon_netconf

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

new "netconf perf tests"

str="<rpc><edit-config><target><candidate/></target><config><interfaces>"
for (( i=0; i<$number; i++ ))
do  
   str+="<interface><name>eth$i</name></interface>"
done
str+="</interfaces></config></edit-config></rpc>]]>]]>"

new "netconf edit large config"
expecteof "$clixon_netconf -qf $clixon_cf" "$str" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get large config"
expecteof "$clixon_netconf -qf $clixon_cf" "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><interfaces><interface><name>eth0</name><enabled>true</enabled></interface>"

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
