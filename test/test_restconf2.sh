#!/bin/bash
# Restconf basic functionality
# Assume http server setup, such as nginx described in apps/restconf/README.md

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/restconf.yang

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/var</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
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
   container types{
     /* A couple of types to test quoting */
     leaf tint {
       type int32;
     }
     leaf tdec64 {
       type decimal64{
         fraction-digits 3;
       }
     }
     leaf tbool {
       type boolean;
     }
     leaf tstr {
       type string;
     }
   }
}
EOF

new "test params: -f $cfg -y $fyang"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg -y $fyang"
    start_backend -s init -f $cfg -y $fyang
fi

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon"
start_restconf -f $cfg -y $fyang

new "waiting"
sleep $RCWAIT

new "restconf tests"

new "restconf POST tree without key"
expectfn 'curl -s -X POST -d {"example:cont1":{"interface":{"type":"regular"}}} http://localhost/restconf/data' 0 '{"ietf-restconf:errors" : {"error": {"error-type": "application","error-tag": "missing-element","error-info": {"bad-element": "name"},"error-severity": "error","error-message": "Mandatory key"}}}'

new "restconf POST initial tree"
expectfn 'curl -s -X POST -d {"example:cont1":{"interface":{"name":"local0","type":"regular"}}} http://localhost/restconf/data' 0 ""

new "restconf GET datastore intial"
expectfn "curl -s -X GET http://localhost/restconf/data/example:cont1" 0 '{"example:cont1": {"interface": \[{"name": "local0","type": "regular"}\]}}'

new "restconf GET interface subtree"
expectfn "curl -s -X GET http://localhost/restconf/data/example:cont1/interface=local0" 0 '{"example:interface": \[{"name": "local0","type": "regular"}\]}'

new "restconf GET interface subtree xml"
ret=$(curl -s -H "Accept: application/yang-data+xml" -G http://localhost/restconf/data/example:cont1/interface=local0)
expect='<interface xmlns="urn:example:clixon"><name>local0</name><type>regular</type></interface>'
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf GET if-type"
expectfn "curl -s -X GET http://localhost/restconf/data/example:cont1/interface=local0/type" 0 '{"example:type": "regular"}'

new "restconf POST interface without mandatory type"
expectfn 'curl -s -X POST http://localhost/restconf/data/example:cont1 -d {"interface":{"name":"TEST"}} http://localhost/restconf/data/example:cont1' 0 '{"ietf-restconf:errors" : {"error": {"error-type": "application","error-tag": "missing-element","error-info": {"bad-element": "type"},"error-severity": "error","error-message": "Mandatory variable"}}}'

new "restconf POST interface without mandatory key"
expectfn 'curl -s -X POST http://localhost/restconf/data/example:cont1 -d {"interface":{"type":"regular"}}' 0 '{"ietf-restconf:errors" : {"error": {"error-type": "application","error-tag": "missing-element","error-info": {"bad-element": "name"},"error-severity": "error","error-message": "Mandatory key"}}}'

new "restconf POST interface"
expectfn 'curl -s -X POST -d {"example:interface":{"name":"TEST","type":"eth0"}} http://localhost/restconf/data/example:cont1' 0 ""

# XXX should it be example:interface?
new "restconf POST again"
expecteq "$(curl -s -X POST -d '{"interface":{"name":"TEST","type":"eth0"}}' http://localhost/restconf/data/example:cont1)" 0 '{"ietf-restconf:errors" : {"error": {"error-type": "application","error-tag": "data-exists","error-severity": "error","error-message": "Data already exists; cannot create new resource"}}}'

new "restconf POST from top"
expecteq "$(curl -s -X POST -d '{"example:cont1":{"interface":{"name":"TEST","type":"eth0"}}}' http://localhost/restconf/data)" 0 '{"ietf-restconf:errors" : {"error": {"error-type": "application","error-tag": "data-exists","error-severity": "error","error-message": "Data already exists; cannot create new resource"}}}'

new "restconf DELETE"
expectfn 'curl -s -X DELETE http://localhost/restconf/data/example:cont1' 0 ""

new "restconf GET null datastore"
expectfn "curl -s -X GET http://localhost/restconf/data/example:cont1" 0 'null'

new "restconf POST initial tree"
expectfn 'curl -s -X POST -d {"example:cont1":{"interface":{"name":"local0","type":"regular"}}} http://localhost/restconf/data' 0 ""

new "restconf GET initial tree"
expectfn "curl -s -X GET http://localhost/restconf/data/example:cont1" 0 '{"example:cont1": {"interface": \[{"name": "local0","type": "regular"}\]}}'

new "restconf DELETE whole datastore"
expectfn 'curl -s -X DELETE http://localhost/restconf/data' 0 ""

new "restconf GET null datastore"
expectfn "curl -s -X GET http://localhost/restconf/data/example:cont1" 0 'null'

new "restconf PUT initial datastore" 
expectfn 'curl -s -X PUT -d {"data":{"example:cont1":{"interface":{"name":"local0","type":"regular"}}}} http://localhost/restconf/data' 0 ""

new "restconf GET datastore"
expectfn "curl -s -X GET http://localhost/restconf/data/example:cont1" 0 '{"example:cont1": {"interface": \[{"name": "local0","type": "regular"}\]}}'

new "restconf PUT replace datastore" 
expectfn 'curl -s -X PUT -d {"data":{"example:cont2":{"name":"foo"}}} http://localhost/restconf/data' 0 ""

new "restconf GET replaced datastore"
expectfn "curl -s -X GET http://localhost/restconf/data/example:cont2" 0 '{"example:cont2": {"name": "foo"}}'

new "restconf PUT initial datastore again" 
expectfn 'curl -s -X PUT -d {"data":{"example:cont1":{"interface":{"name":"local0","type":"regular"}}}} http://localhost/restconf/data' 0 ""

new "restconf PUT change interface"
expectfn 'curl -s -X PUT -d {"interface":{"name":"local0","type":"atm0"}} http://localhost/restconf/data/example:cont1/interface=local0' 0 ""

new "restconf GET datastore atm"
expectfn "curl -s -X GET http://localhost/restconf/data/example:cont1" 0 '{"example:cont1": {"interface": \[{"name": "local0","type": "atm0"}\]}}'

new "restconf PUT add interface"
expectfn 'curl -s -X PUT -d {"interface":{"name":"TEST","type":"eth0"}} http://localhost/restconf/data/example:cont1/interface=TEST' 0 ""

new "restconf PUT change key error"
expectfn 'curl -is -X PUT -d {"interface":{"name":"ALPHA","type":"eth0"}} http://localhost/restconf/data/example:cont1/interface=TEST' 0 '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "operation-failed","error-severity": "error","error-message": "api-path keys do not match data keys"}}}'

#--------------- json type tests
new "restconf POST type x3"
expectfn 'curl -s -X POST -d {"example:types":{"tint":42,"tdec64":42.123,"tbool":false,"tstr":"str"}} http://localhost/restconf/data' 0 ''

new "restconf POST type x3"
expectfn 'curl -s -X GET http://localhost/restconf/data/example:types' 0 '{"example:types": {"tint": 42,"tdec64": 42.123,"tbool": false,"tstr": "str"}}'

new "Kill restconf daemon"
stop_restconf 

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
