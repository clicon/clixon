#!/bin/bash
# Restconf RFC8040 plain patch Sec 4.6 / 4.6.1

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fjukebox=$dir/example-jukebox.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fjukebox</CLICON_YANG_MAIN_FILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Common Jukebox spec (fjukebox must be set)
. ./jukebox.sh

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
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

# also in test_restconf.sh
new "MUST support the PATCH method for a plain patch" 
expectpart "$(curl -is -X OPTIONS http://localhost/restconf/data)" 0 "HTTP/1.1 200 OK" "Allow: OPTIONS,HEAD,GET,POST,PUT,PATCH,DELETE" "Accept-Patch: application/yang-data+xml,application/yang-data+json"

new "If the target resource instance does not exist, the server MUST NOT create it."
expectpart "$(curl -si -X PATCH -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox -d '{"example-jukebox:jukebox":null}')" 0 "HTTP/1.1 400 Bad Request"

new "Create it with PUT instead"
expectpart "$(curl -si -X PUT -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox -d '{"example-jukebox:jukebox":null}')" 0 "HTTP/1.1 201 Created"

new "THEN change it with PATCH"
expectpart "$(curl -si -X PATCH -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox -d '{"example-jukebox:jukebox":{"library":{"artist":{"name":"Clash"}}}}')" 0 "HTTP/1.1 204 No Content"

new "Check content"
expectpart "$(curl -si -X GET http://localhost/restconf/data/example-jukebox:jukebox -H 'Accept: application/yang-data+json')" 0 'HTTP/1.1 200 OK' '{"example-jukebox:jukebox":{"library":{"artist":\[{"name":"Clash"}\]}}}'


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
