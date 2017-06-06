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

new "restconf tests"

new "restconf options"
expectfn "curl -i -sS -X OPTIONS http://localhost/restconf/data" "Allow: OPTIONS,HEAD,GET,POST,PUT,DELETE"

new "restconf head"
expectfn "curl -sS -I http://localhost/restconf/data" "Content-Type: application/yang.data\+json"

new "restconf get empty config"
expectfn "curl -sSG http://localhost/restconf/data" "^null$"

# 
new "Add subtree  to datastore using POST"
expectfn 'curl -sS -X POST -d {"interfaces":{"interface":{"name":"eth/0/0","type":"eth","enabled":"true"}}} http://localhost/restconf/data' ""

new "Check interfaces eth/0/0 added"
expectfn "curl -sS -G http://localhost/restconf/data" '{"interfaces": {"interface": {"name": "eth/0/0","type": "eth","enabled": "true"}}}
$'

new "delete interfaces"
expectfn 'curl -sS -X DELETE  http://localhost/restconf/data/interfaces' ""

new "Check empty config"
expectfn "curl -sSG http://localhost/restconf/data" "^null$"



new "Add interfaces subtree eth/0/0 using POST"
expectfn 'curl -sS -X POST -d {"interface":{"name":"eth/0/0","type":"eth","enabled":"true"}} http://localhost/restconf/data/interfaces' ""

new "Check eth/0/0 added"
expectfn "curl -sS -G http://localhost/restconf/data" '{"interfaces": {"interface": {"name": "eth/0/0","type": "eth","enabled": "true"}}}
$'

new "Re-post eth/0/0 which should generate error"
expectfn 'curl -sS -X POST -d {"interface":{"name":"eth/0/0","type":"eth","enabled":"true"}} http://localhost/restconf/data/interfaces' "Data resource already exists"

new "Add leaf description using POST"
expectfn 'curl -sS -X POST -d {"description":"The-first-interface"} http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0' ""

new "Check description added"
expectfn "curl -sS -G http://localhost/restconf/data" '{"interfaces": {"interface": {"name": "eth/0/0","description": "The-first-interface","type": "eth","enabled": "true"}}
$'

new "delete eth/0/0"
expectfn 'curl -sS -X DELETE  http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0' ""

#new "Check deleted eth/0/0"
#expectfn 'curl -sS -G http://localhost/restconf/data' '{"interfaces": null}
#$'

new "Re-Delete eth/0/0 using none should generate error"
expectfn 'curl -sS -X DELETE  http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0' "Not Found"

new "Add subtree eth/0/0 using PUT"
expectfn 'curl -sS -X PUT -d {"interface":{"name":"eth/0/0","type":"eth","enabled":"true"}} http://localhost/restconf/data/interfaces/interface=eth%2f0%2f0' ""

expectfn "curl -sS -G http://localhost/restconf/data" '{"interfaces": {"interface": {"name": "eth/0/0","type": "eth","enabled": "true"}}}
$'

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
