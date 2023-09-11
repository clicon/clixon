#!/usr/bin/env bash
# Testcases for Restconf list and leaf-list keys, check matching keys for RFC8040 4.5:
# the key values must match in URL and data
# Empty keys vs comma as a key

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/list.yang

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang
module list{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   container c{
      list a{
         key "b c";
         leaf b{
            type string;
         }
         leaf c{
            type string;
         }
         leaf nonkey{
            description "non-key element";
            type string;
         }
         list e{
           description "A list in a list";
           key "f";
           leaf f{
             type string;
           }
           leaf nonkey{
              type string;
           }
         }
         leaf-list f{
           type string;
         }
      }
      leaf-list d{
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

new "restconf PUT add whole list entry"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y -d '{"list:a":{"b":"x","c":"y","nonkey":"0"}}')" 0 "HTTP/$HVER 201"

# GETs to ensure you get list [] in JSON
new "restconf GET whole list entry"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/)" 0 "HTTP/$HVER 200" '{"list:c":{"a":\[{"b":"x","c":"y","nonkey":"0"}\]}}'

new "restconf GET list entry itself (should fail)"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a)" 0 "HTTP/$HVER 400" '^{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"malformed key =a, expected '

new "restconf GET list entry"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y)" 0 "HTTP/$HVER 200" '{"list:a":\[{"b":"x","c":"y","nonkey":"0"}\]}'

new "restconf PUT add whole list entry XML"
expectpart "$(curl $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+xml' -H 'Accept: application/yang-data+xml' -d '<a xmlns="urn:example:clixon"><b>xx</b><c>xy</c><nonkey>0</nonkey></a>' $RCPROTO://localhost/restconf/data/list:c/a=xx,xy)" 0 "HTTP/$HVER 201"

new "restconf GET sub key"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a/b)" 0 "HTTP/$HVER 400" '^{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"malformed key =a, expected '

new "restconf PUT change whole list entry (same keys)"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y -d '{"list:a":{"b":"x","c":"y","nonkey":"z"}}')" 0 "HTTP/$HVER 204"

new "restconf PUT change whole list entry (no namespace)(expect fail)"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y -d '{"a":{"b":"x","c":"y","nonkey":"z"}}')" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"Top-level JSON object a is not qualified with namespace which is a MUST according to RFC 7951"}}}'

new "restconf PUT change list entry (wrong keys)(expect fail)"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y -d '{"list:a":{"b":"y","c":"x"}}')" 0 "HTTP/$HVER 412" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'

new "restconf PUT change list entry (wrong keys)(expect fail) XML"
expectpart "$(curl $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+xml' -H 'Accept: application/yang-data+xml' -d '<a xmlns="urn:example:clixon"><b>xy</b><c>xz</c><nonkey>0</nonkey></a>' $RCPROTO://localhost/restconf/data/list:c/a=xx,xy)" 0 "HTTP/$HVER 412" '<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>api-path keys do not match data keys</error-message></error></errors>'

new "restconf PUT change list entry (just one key)(expect fail)"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x -d '{"list:a":{"b":"x"}}')" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"List key a length mismatch"}}}'

new "restconf PUT sub non-key"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/nonkey -d '{"list:nonkey":"u"}')" 0 "HTTP/$HVER 204"

new "restconf PUT sub key same value"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/b -d '{"list:b":"x"}')" 0 "HTTP/$HVER 204"

new "restconf PUT just key other value (should fail)"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x/b -d '{"b":"y"}')" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"List key a length mismatch"}}}'

new "restconf PUT add leaf-list entry"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/d=x -d '{"list:d":"x"}')" 0 "HTTP/$HVER 201"

new "restconf PUT change leaf-list entry (expect fail)"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/d=x -d '{"list:d":"y"}')" 0 "HTTP/$HVER 412" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'

new "restconf PUT list-list"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/e=z -d '{"list:e":{"f":"z","nonkey":"0"}}')" 0 "HTTP/$HVER 201"

new "restconf GET e element with empty string key expect empty"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/e=)" 0 "HTTP/$HVER 404" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

new "restconf PUT list-list empty string"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/e= -d '{"list:e":{"f":"","nonkey":"42"}}')" 0 "HTTP/$HVER 201"

new "restconf GET e element with empty string key"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/list:c/a=x,y/e=)" 0 "HTTP/$HVER 200" '<e xmlns="urn:example:clixon"><f/><nonkey>42</nonkey></e>'

new "restconf PUT change list-lst entry (wrong keys)(expect fail)"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/e=z -d '{"list:e":{"f":"wrong","nonkey":"0"}}')" 0 "HTTP/$HVER 412" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'

new "restconf PUT list-list sub non-key"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/e=z/nonkey -d '{"list:nonkey":"u"}')" 0 "HTTP/$HVER 204"

new "restconf PUT list-list single first key"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x/e=z/f -d '{"f":"z"}')" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"List key a length mismatch"}}}'

new "restconf PUT list-list just key ok"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/e=z/f -d '{"list:f":"z"}')" 0 "HTTP/$HVER 204"

new "restconf PUT list-list just key just key wrong value (should fail)"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/e=z/f -d '{"list:f":"wrong"}')" 0 "HTTP/$HVER 412" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'

new "restconf PUT add list+leaf-list entry"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/f=u -d '{"list:f":"u"}')" 0 "HTTP/$HVER 201"

new "restconf PUT change list+leaf-list entry (expect fail)"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,y/f=u -d '{"list:f":"w"}')" 0 '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'

new "restconf PUT (x,y),z -> x%2Cy,z percent-encoded"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x%2Cy,z/nonkey -d '{"list:nonkey":"foo"}')" 0 "HTTP/$HVER 201"

new "restconf GET check percent-encoded"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x%2Cy,z)" 0 "HTTP/$HVER 200" '{"list:a":\[{"b":"x,y","c":"z","nonkey":"foo"}\]}'

new "restconf PUT ,z empty string as first key"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=,z -d '{"list:a":{"b":"","c":"z", "nonkey":"42"}}')" 0 "HTTP/$HVER 201"

new "restconf GET ,z empty"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=,z)" 0 "HTTP/$HVER 200" '{"list:a":\[{"b":"","c":"z","nonkey":"42"}\]}'

new "restconf PUT x, empty string as second key"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x, -d '{"list:a":{"b":"x","c":"", "nonkey":"43"}}')" 0 "HTTP/$HVER 201"

new "restconf GET x, empty"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=x,)" 0 "HTTP/$HVER 200" '{"list:a":\[{"b":"x","c":"","nonkey":"43"}\]}'

new "restconf PUT , empty string as second key"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=, -d '{"list:a":{"b":"","c":"", "nonkey":"44"}}')" 0 "HTTP/$HVER 201"

new "restconf GET , empty"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=,)" 0 "HTTP/$HVER 200" '{"list:a":\[{"b":"","c":"","nonkey":"44"}\]}'

new "restconf PUT two commas as keys"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=%2C,%2C -d '{"list:a":{"b":",","c":",", "nonkey":"45"}}')" 0 "HTTP/$HVER 201"

new "restconf GET two commas"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c/a=%2C,%2C)" 0 "HTTP/$HVER 200" '{"list:a":\[{"b":",","c":",","nonkey":"45"}\]}'

new "restconf GET all empty strings"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data/list:c)" 0 "HTTP/$HVER 200" '{"list:c":{"a":\[{"b":"","c":"","nonkey":"44"},{"b":"","c":"z","nonkey":"42"},{"b":",","c":",","nonkey":"45"},{"b":"x","c":"","nonkey":"43"}'

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
