#!/usr/bin/env bash
# Testcases for Restconf list and leaf-list keys, check matching keys for RFC8040 4.5:
# the key values must match in URL and data

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/list.yang

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
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
    sudo pkill clixon_backend # to be sure
    
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "kill old restconf daemon"
sudo pkill -u $wwwuser clixon_restconf

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

new "restconf PUT add whole list entry"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y -d '{"list:a":{"b":"x","c":"y","nonkey":"0"}}')" 0 ''

new "restconf PUT add whole list entry XML"
expecteq "$(curl -s -X PUT -H 'Content-Type: application/yang-data+xml' -H 'Accept: application/yang-data+xml' -d '<a xmlns="urn:example:clixon"><b>xx</b><c>xy</c><nonkey>0</nonkey></a>' http://localhost/restconf/data/list:c/a=xx,xy)" 0 ''

new "restconf PUT change whole list entry (same keys)"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y -d '{"list:a":{"b":"x","c":"y","nonkey":"z"}}')" 0 ''

new "restconf PUT change whole list entry (no namespace)(expect fail)"
expectpart "$(curl -is -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y -d '{"a":{"b":"x","c":"y","nonkey":"z"}}')" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"Data is not prefixed with matching namespace"}}}'

new "restconf PUT change list entry (wrong keys)(expect fail)"
expectpart "$(curl -is -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y -d '{"list:a":{"b":"y","c":"x"}}')" 0 '412 Precondition Failed' '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'

new "restconf PUT change list entry (wrong keys)(expect fail) XML"
expecteq "$(curl -s -X PUT -H 'Content-Type: application/yang-data+xml' -H 'Accept: application/yang-data+xml' -d '<a xmlns="urn:example:clixon"><b>xy</b><c>xz</c><nonkey>0</nonkey></a>' http://localhost/restconf/data/list:c/a=xx,xy)" 0 '<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>api-path keys do not match data keys</error-message></error></errors>'

new "restconf PUT change list entry (just one key)(expect fail)"
expectpart "$(curl -is -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x -d '{"list:a":{"b":"x"}}')" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"List key a length mismatch"}}}'

new "restconf PUT sub non-key"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y/nonkey -d '{"list:nonkey":"u"}')" 0 ''

new "restconf PUT sub key same value"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y/b -d '{"list:b":"x"}')" 0 ''

new "restconf PUT just key other value (should fail)"
expectpart "$(curl -is -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x/b -d '{"b":"y"}')" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"List key a length mismatch"}}}'

new "restconf PUT add leaf-list entry"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/d=x -d '{"list:d":"x"}')" 0 ''

new "restconf PUT change leaf-list entry (expect fail)"
expectpart "$(curl -is -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/d=x -d '{"list:d":"y"}')" 0 'HTTP/1.1 412 Precondition Failed' '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'

new "restconf PUT list-list"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y/e=z -d '{"list:e":{"f":"z","nonkey":"0"}}')" 0 ''

new "restconf PUT change list-lst entry (wrong keys)(expect fail)"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y/e=z -d '{"list:e":{"f":"wrong","nonley":"0"}}')" 0 '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'

new "restconf PUT list-list sub non-key"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y/e=z/nonkey -d '{"list:nonkey":"u"}')" 0 ''

new "restconf PUT list-list single first key"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x/e=z/f -d '{"f":"z"}')" 0 '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"List key a length mismatch"}}}'

new "restconf PUT list-list just key ok"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y/e=z/f -d '{"list:f":"z"}')" 0 ''

new "restconf PUT list-list just key just key wrong value (should fail)"
expectpart "$(curl -is -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y/e=z/f -d '{"list:f":"wrong"}')" 0 'HTTP/1.1 412 Precondition Failed' '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'

new "restconf PUT add list+leaf-list entry"
expecteq "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y/f=u -d '{"list:f":"u"}')" 0 ''

new "restconf PUT change list+leaf-list entry (expect fail)"
expectpart "$(curl -s -X PUT -H "Content-Type: application/yang-data+json" http://localhost/restconf/data/list:c/a=x,y/f=u -d '{"list:f":"w"}')" 0 '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"api-path keys do not match data keys"}}}'


new "Kill restconf daemon"
stop_restconf 

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
