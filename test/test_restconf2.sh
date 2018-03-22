#!/bin/bash
# Restconf basic functionality
# Assume http server setup, such as nginx described in apps/restconf/README.md

# include err() and new() functions and creates $dir
. ./lib.sh
cfg=$dir/conf.xml
fyang=$dir/restconf.yang

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/var</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>$fyang</CLICON_YANG_MODULE_MAIN>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/routing/routing.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/routing</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

cat <<EOF > $fyang
module example{
   container cont1{
      list interface{
        key name;
        leaf name{
          type string;
        }
        leaf type{
          mandatory true;
          type string;
        }
      }
   }
   container cont2{
      leaf name{
         type string;
      }
   }
}
EOF

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err
fi
new "start backend -s init -f $cfg -y $fyang"
sudo clixon_backend -s init -f $cfg -y $fyang
if [ $? -ne 0 ]; then
    err
fi

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
sudo start-stop-daemon -S -q -o -b -x /www-data/clixon_restconf -d /www-data -c www-data -- -Df $cfg

sleep 1

new "restconf tests"

new "restconf POST initial tree"
expectfn 'curl -s -X POST -d {"cont1":{"interface":{"name":"local0","type":"regular"}}} http://localhost/restconf/data' ""

new "restconf GET datastore"
expectfn "curl -s -X GET http://localhost/restconf/data" '{"data": {"cont1": {"interface": \[{"name": "local0","type": "regular"}\]}}}'

new "restconf GET interface"
expectfn "curl -s -X GET http://localhost/restconf/data/cont1/interface=local0" '{"interface": \[{"name": "local0","type": "regular"}\]}'

new "restconf GET if-type"
expectfn "curl -s -X GET http://localhost/restconf/data/cont1/interface=local0/type" '{"type": "regular"}'

new "restconf POST interface without mandatory type"
expectfn 'curl -s -X POST -d {"interface":{"name":"TEST"}} http://localhost/restconf/data/cont1' '"error-message": "Missing mandatory variable: type"'

new "restconf POST interface"
expectfn 'curl -s -X POST -d {"interface":{"name":"TEST","type":"eth0"}} http://localhost/restconf/data/cont1' ""

new "restconf POST again"
expecteq 'curl -s -X POST -d {"interface":{"name":"TEST","type":"eth0"}} http://localhost/restconf/data/cont1' '{"ietf-restconf:errors" : {"error": {"error-tag": "data-exists","error-type": "application","error-severity": "error","error-message": "Data already exists; cannot create new resource"}}}'

new "restconf POST from top"
expecteq 'curl -s -X POST -d {"cont1":{"interface":{"name":"TEST","type":"eth0"}}} http://localhost/restconf/data' '{"ietf-restconf:errors" : {"error": {"error-tag": "data-exists","error-type": "application","error-severity": "error","error-message": "Data already exists; cannot create new resource"}}}'

new "restconf DELETE"
expectfn 'curl -s -X DELETE http://localhost/restconf/data/cont1' ""

new "restconf GET null datastore"
expectfn "curl -s -X GET http://localhost/restconf/data" '{"data": null}'

new "restconf POST initial tree"
expectfn 'curl -s -X POST -d {"cont1":{"interface":{"name":"local0","type":"regular"}}} http://localhost/restconf/data' ""

new "restconf GET initial tree"
expectfn "curl -s -X GET http://localhost/restconf/data" '{"data": {"cont1": {"interface": \[{"name": "local0","type": "regular"}\]}}}'

new "restconf DELETE whole datastore"
expectfn 'curl -s -X DELETE http://localhost/restconf/data' ""

new "restconf GET null datastore"
expectfn "curl -s -X GET http://localhost/restconf/data" '{"data": null}'

new "restconf PUT initial datastore" 
expectfn 'curl -s -X PUT -d {"data":{"cont1":{"interface":{"name":"local0","type":"regular"}}}} http://localhost/restconf/data' ""

new "restconf GET datastore"
expectfn "curl -s -X GET http://localhost/restconf/data" '{"data": {"cont1": {"interface": \[{"name": "local0","type": "regular"}\]}}}'

new "restconf PUT replace datastore" 
expectfn 'curl -s -X PUT -d {"data":{"cont2":{"name":"foo"}}} http://localhost/restconf/data' ""

new "restconf GET replaced datastore"
expectfn "curl -s -X GET http://localhost/restconf/data" '{"data": {"cont2": {"name": "foo"}}}'


new "restconf PUT initial datastore again" 
expectfn 'curl -s -X PUT -d {"data":{"cont1":{"interface":{"name":"local0","type":"regular"}}}} http://localhost/restconf/data' ""

new "restconf PUT change interface"
expectfn 'curl -s -X PUT -d {"interface":{"name":"local0","type":"atm0"}} http://localhost/restconf/data/cont1/interface=local0' ""


new "restconf GET datastore atm"
expectfn "curl -s -X GET http://localhost/restconf/data" '{"data": {"cont1": {"interface": \[{"name": "local0","type": "atm0"}\]}}}'

new "restconf PUT add interface"
expectfn 'curl -s -X PUT -d {"interface":{"name":"TEST","type":"eth0"}} http://localhost/restconf/data/cont1/interface=TEST' ""

new "restconf PUT change key error"
expectfn 'curl -is -X PUT -d {"interface":{"name":"ALPHA","type":"eth0"}} http://localhost/restconf/data/cont1/interface=TEST' "Bad request"

new "Kill restconf daemon"
sudo pkill -u www-data clixon_restconf

new "Kill backend"
# Check if still alive
pid=`pgrep clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
