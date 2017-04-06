#!/bin/bash
# Test3: backend and restconf basic functionality

# include err() and new() functions
. ./lib.sh

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $clixon_cf
if [ $? -ne 0 ]; then
    err
fi
new "start backend"
sudo clixon_backend -If $clixon_cf
if [ $? -ne 0 ]; then
    err
fi

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
sudo start-stop-daemon -S -q -o -b -x /www-data/clixon_restconf -d /www-data -c www-data -- -Df /usr/local/etc/routing.conf # -D

sleep 1

new "restconf options"
expectfn "curl -i -s -X OPTIONS http://localhost/restconf/data" "Allow: OPTIONS,HEAD,GET,POST,PUT,DELETE"

new "restconf get empty config"
expectfn "curl -sG http://localhost/restconf/data" "^null$"

new "restconf put config"
expectfn 'curl -sX POST -d {"interfaces":{"interface":[{"name":"eth1","type":"eth","enabled":"true"},{"name":"eth0","type":"eth","enabled":"true"}]}} http://localhost/restconf/data' ""

new "restconf get config"
expectfn "curl -sG http://localhost/restconf/data" '{"interfaces": {"interface": \[{"name": "eth1","type": "eth","enabled": "true"},{ "name": "eth0","type": "eth","enabled": "true"}\]}}
$'

new "restconf head"
expectfn "curl -s -I http://localhost/restconf/data" "Content-Type: application/yang.data\+json"

new "restconf POST config"
expectfn 'curl -sX POST -d {"type":"eth"} http://localhost/restconf/data/interfaces/interface=eth4' ""

new "restconf DELETE config"
expectfn 'curl -sX DELETE  http://localhost/restconf/data/interfaces/interface=eth0' ""

new "restconf get config"
expectfn "curl -sG http://localhost/restconf/data" '{"interfaces": {"interface": \[{"name": "eth1","type": "eth","enabled": "true"},{ "name": "eth4","type": "eth","enabled": "true"}\]}}
$'

new "restconf PATCH config"
expectfn 'curl -sX PATCH -d {"type":"eth"} http://localhost/restconf/data/interfaces/interface=eth4' ""

new "restconf PUT"
expectfn 'curl -sX PUT -d {"type":"eth"} http://localhost/restconf/data/interfaces/interface=eth5' ""

new "Kill restconf daemon"
#sudo pkill -u www-data clixon_restconf

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
