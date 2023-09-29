#!/usr/bin/env bash
# Restconf basic functionality
# Assume http server setup, such as nginx described in apps/restconf/README.md
# Systematic tests of restconf operations GET/POST/PUT/DELETE
# Also multiple requests
# See also test_restconf.sh

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/restconf.yang

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  $RESTCONFIG
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

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend # to be sure

    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend


if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

new "restconf POST tree without key"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"example:cont1":{"interface":{"type":"regular"}}}' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 400" "{\"ietf-restconf:errors\":{\"error\":{\"error-type\":\"application\",\"error-tag\":\"missing-element\",\"error-info\":{\"bad-element\":\"name\"},\"error-severity\":\"error\",\"error-message\":\"Mandatory key in 'list interface' in example.yang:7\"}}}"

new "restconf POST initial tree"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"example:cont1":{"interface":{"name":"local0","type":"regular"}}}' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 201"

new "restconf POST top without namespace"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"cont1":{"interface":{"name":"local0","type":"regular"}}}' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"Top-level JSON object cont1 is not qualified with namespace which is a MUST according to RFC 7951"}}}'

new "restconf GET datastore initial"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:cont1)" 0 "HTTP/$HVER 200" '{"example:cont1":{"interface":\[{"name":"local0","type":"regular"}\]}}'

new "restconf GET interface subtree"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:cont1/interface=local0)" 0 "HTTP/$HVER 200" '{"example:interface":\[{"name":"local0","type":"regular"}\]}'

new "restconf PUT interface without media"
expectpart "$(curl $CURLOPTS -X PUT $RCPROTO://localhost/restconf/data/example:cont1/interface=local0 -d '{"example:interface":{"name":"local0","type":"foo"}}')" 0 "HTTP/$HVER 415" 

new "restconf GET interface subtree xml"
ret=$(curl $CURLOPTS -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data/example:cont1/interface=local0)
expect='<interface xmlns="urn:example:clixon"><name>local0</name><type>regular</type></interface>'
match=`echo $ret | grep --null -Eo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

new "restconf GET if-type"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:cont1/interface=local0/type)" 0 "HTTP/$HVER 200" '{"example:type":"regular"}'

new "restconf POST interface without mandatory type"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example:cont1 -d '{"example:interface":{"name":"TEST"}}')" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"missing-element","error-info":{"bad-element":"type"},"error-severity":"error","error-message":"Mandatory variable of interface in module example"}}}'

new "restconf POST interface without mandatory key"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example:cont1 -d '{"example:interface":{"type":"regular"}}')" 0 "HTTP/$HVER 400" "{\"ietf-restconf:errors\":{\"error\":{\"error-type\":\"application\",\"error-tag\":\"missing-element\",\"error-info\":{\"bad-element\":\"name\"},\"error-severity\":\"error\",\"error-message\":\"Mandatory key in 'list interface' in example.yang:7\"}}}"

new "restconf POST interface"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"example:interface":{"name":"TEST","type":"eth0"}}' $RCPROTO://localhost/restconf/data/example:cont1)" 0 "HTTP/$HVER 201"

new "restconf POST interface without namespace"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"interface":{"name":"TEST2","type":"eth0"}}' $RCPROTO://localhost/restconf/data/example:cont1)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"Top-level JSON object interface is not qualified with namespace which is a MUST according to RFC 7951"}}}'

new "restconf POST again"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example:cont1 -d '{"example:interface":{"name":"TEST","type":"eth0"}}')" 0 "HTTP/$HVER 409" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-exists","error-severity":"error","error-message":"Data already exists; cannot create new resource"}}}'

new "restconf POST from top"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data -d '{"example:cont1":{"interface":{"name":"TEST","type":"eth0"}}}')" 0 "HTTP/$HVER 409" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-exists","error-severity":"error","error-message":"Data already exists; cannot create new resource"}}}'

new "restconf DELETE"
expectpart "$(curl $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/example:cont1)" 0 "HTTP/$HVER 204"

new "restconf POST from top containing duplicate keys expect error"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data -d '{"example:cont1":{"interface":[{"name":"TEST","type":"eth0"},{"name":"TEST","type":"eth0"}]}}')" 0 "HTTP/$HVER 412" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"operation-failed","error-app-tag":"data-not-unique","error-severity":"error","error-info":{"non-unique":"/rpc/edit-config/config/cont1/interface\[name=\\"TEST\\"\]/name"}}}}'

new "restconf GET null datastore"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:cont1)" 0 "HTTP/$HVER 404" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

new "restconf POST initial tree"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"example:cont1":{"interface":{"name":"local0","type":"regular"}}}' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 201"

new "restconf GET initial tree"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:cont1)" 0 "HTTP/$HVER 200" '{"example:cont1":{"interface":\[{"name":"local0","type":"regular"}\]}}'

new "restconf DELETE whole datastore"
expectpart "$(curl $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 204"

new "restconf GET null datastore"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:cont1)" 0 "HTTP/$HVER 404" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

new "restconf PUT initial datastore" 
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-restconf:data":{"example:cont1":{"interface":{"name":"local0","type":"regular"}}}}' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 201"

new "restconf GET datastore"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:cont1)" 0 "HTTP/$HVER 200" '{"example:cont1":{"interface":\[{"name":"local0","type":"regular"}\]}}'

new "restconf PUT replace datastore" 
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-restconf:data":{"example:cont2":{"name":"foo"}}}' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 204"

new "restconf GET replaced datastore"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:cont2)" 0 "HTTP/$HVER 200" '{"example:cont2":{"name":"foo"}}'

new "restconf PUT initial datastore again" 
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-restconf:data":{"example:cont1":{"interface":{"name":"local0","type":"regular"}}}}' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 204"

new "restconf PUT change interface"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"example:interface":{"name":"local0","type":"atm0"}}' $RCPROTO://localhost/restconf/data/example:cont1/interface=local0)" 0 "HTTP/$HVER 204"

new "restconf GET datastore atm"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:cont1)" 0 "HTTP/$HVER 200" '{"example:cont1":{"interface":\[{"name":"local0","type":"atm0"}\]}}'

new "restconf PUT add interface"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"example:interface":{"name":"TEST","type":"eth0"}}' $RCPROTO://localhost/restconf/data/example:cont1/interface=TEST)" 0 "HTTP/$HVER 201"

new "restconf PUT change key error"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"example:interface":{"name":"ALPHA","type":"eth0"}}' $RCPROTO://localhost/restconf/data/example:cont1/interface=TEST)" 0 "HTTP/$HVER 412" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'

new "restconf PUT change type to eth0 (non-key sub-element to list)"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"example:type":"eth0"}' $RCPROTO://localhost/restconf/data/example:cont1/interface=local0/type)" 0 "HTTP/$HVER 204"

new "restconf GET datastore eth"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:cont1/interface=local0)" 0 "HTTP/$HVER 200" '{"example:interface":\[{"name":"local0","type":"eth0"}\]}'

new "restconf DELETE whole datastore"
expectpart "$(curl $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 204"

#--------------- Multiple request in single TCP tests
# GET + GET
new "Multiple requests: GET + GET using --next"
expectpart "$(curl $CURLOPTS -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data?content=config --next $CURLOPTS -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data?content=config)" 0 "HTTP/$HVER 200" "<data $DEFAULTONLY/>"

if [ ${HAVE_HTTP1} = true ]; then
    new "Multiple requests: GET + GET http/1"
    expectpart "$(curl $CURLOPTS --http1.1 -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data?content=config --next $CURLOPTS --http1.1 -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data?content=config)" 0 "HTTP/1.1 200" "<data $DEFAULTONLY/>"
fi

# GET + POST
new "Multiple requests: GET + POST using --next"
expectpart "$(curl $CURLOPTS -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data?content=config --next $CURLOPTS -H "Content-Type: application/yang-data+json" -X POST $RCPROTO://localhost/restconf/data -d '{"example:cont1":{"interface":{"name":"local0","type":"regular"}}}')" 0 "HTTP/$HVER 200" "<data $DEFAULTONLY/>" "HTTP/$HVER 201"

if [ ${HAVE_HTTP1} = true ]; then
    new "Multiple requests: GET + POST http/1"
    expectpart "$(curl $CURLOPTS --http1.1 -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data?content=config --next $CURLOPTS --http1.1 -H "Content-Type: application/yang-data+json" -X POST $RCPROTO://localhost/restconf/data -d '{"example:cont1":{"interface":{"name":"local5","type":"regular"}}}')" 0 "HTTP/1.1 200"
fi

# POST + POST
new "Multiple requests: POST + POST"
expectpart "$(curl $CURLOPTS -H "Content-Type: application/yang-data+json" -X POST $RCPROTO://localhost/restconf/data/example:cont1 -d '{"example:interface":{"name":"local1","type":"regular"}}' --next $CURLOPTS -H "Content-Type: application/yang-data+json" -X POST $RCPROTO://localhost/restconf/data/example:cont1 -d '{"example:interface":{"name":"local2","type":"regular"}}')" 0 "HTTP/$HVER 201" "localhost/restconf/data/example:cont1/interface=local1" "localhost/restconf/data/example:cont1/interface=local2"

if [ ${HAVE_HTTP1} = true ]; then
    new "Multiple requests: POST + POST http/1"
    expectpart "$(curl $CURLOPTS --http1.1 -H "Content-Type: application/yang-data+json" -X POST $RCPROTO://localhost/restconf/data/example:cont1 -d '{"example:interface":{"name":"local7","type":"regular"}}' --next $CURLOPTS --http1.1 -H "Content-Type: application/yang-data+json" -X POST $RCPROTO://localhost/restconf/data/example:cont1 -d '{"example:interface":{"name":"local8","type":"regular"}}')" 0 "HTTP/1.1 201" "localhost/restconf/data/example:cont1/interface=local7" "localhost/restconf/data/example:cont1/interface=local8"

fi

#--------------- json type tests
new "restconf POST type x3 POST"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"example:types":{"tint":42,"tdec64":"42.123","tbool":false,"tstr":"str"}}' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 201" "Location: $RCPROTO://localhost/restconf/data/example:types"

new "restconf POST type x3 GET"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:types)" 0 "HTTP/$HVER 200" '{"example:types":{"tint":42,"tdec64":"42.123","tbool":false,"tstr":"str"}}'

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf 
fi

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
