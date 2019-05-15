#!/bin/bash
# Testcases for lists, key operations for netconf and restconf

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/list.yang

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/var</CLICON_YANG_DIR>
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
         key b;
         leaf b{
            type string;
         }
         leaf c{
            type string;
         }
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
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

new "restconf PUT add entry"
expectfn 'curl -s -X PUT http://localhost/restconf/data/list:c/a=x -d {"list:a":{"b":"x","c":"0"}}' 0 ''

new "restconf PUT change regular entry"
expectfn 'curl -s -X PUT http://localhost/restconf/data/list:c/a=x -d {"list:a":{"b":"x","c":"z"}}' 0 ''

new "restconf PUT change key entry"
expectfn 'curl -s -X PUT http://localhost/restconf/data/list:c/a=x -d {"list:a":{"b":"y"}}' 0 '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "operation-failed","error-severity": "error","error-message": "api-path keys do not match data keys"}}}'

new "restconf PUT change actual key entry"
expectfn 'curl -s -X PUT http://localhost/restconf/data/list:c/a=x/b -d {"b":"y"}' 0 '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "operation-failed","error-severity": "error","error-message": "api-path keys do not match data keys"}}}'
exit

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
