#!/bin/bash
# Restconf RFC8040 Appendix A and B "jukebox" example

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fjukebox=$dir/example-jukebox.yang

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
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
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
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

new "B.1.1.  Retrieve the Top-Level API Resource root"
expectpart "$(curl -s -i -X GET -H 'Accept: application/xrd+xml' http://localhost/.well-known/host-meta)" 0 "HTTP/1.1 200 OK" "Content-Type: application/xrd+xml" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"

d='{"ietf-restconf:restconf":{"data":{},"operations":{},"yang-library-version":"2016-06-21"}}'
new "B.1.1.  Retrieve the Top-Level API Resource /restconf json"
expectpart "$(curl -s -i -X GET -H 'Accept: application/yang-data+json' http://localhost/restconf)" 0 "HTTP/1.1 200 OK" 'Cache-Control: no-cache' "Content-Type: application/yang-data+json" "$d"

new "B.1.1.  Retrieve the Top-Level API Resource /restconf xml (not in RFC)"
expectpart "$(curl -s -i -X GET -H 'Accept: application/yang-data+xml' http://localhost/restconf)" 0 "HTTP/1.1 200 OK" 'Cache-Control: no-cache' "Content-Type: application/yang-data+xml" '<restconf xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><data/><operations/><yang-library-version>2016-06-21</yang-library-version></restconf>'

# This just catches the header and the jukebox module, the RFC has foo and bar which
# seems wrong to recreate
new "B.1.2.  Retrieve the Server Module Information"
expectpart "$(curl -s -i -X GET -H 'Accept: application/yang-data+json' http://localhost/restconf/data/ietf-yang-library:modules-state)" 0 "HTTP/1.1 200 OK" 'Cache-Control: no-cache' "Content-Type: application/yang-data+json" '{"ietf-yang-library:modules-state":{"module-set-id":' '"module":\[{"name":"example-jukebox","revision":"2016-08-15","namespace":"http://example.com/ns/example-jukebox","conformance-type":"implement"}'

new "B.1.3.  Retrieve the Server Capability Information"
expectpart "$(curl -s -i -X GET -H 'Accept: application/yang-data+xml' http://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/capabilities)" 0 "HTTP/1.1 200 OK" "Content-Type: application/yang-data+xml" 'Cache-Control: no-cache' '<capabilities xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf-monitoring"><capability>urn:ietf:params:restconf:capability:defaults:1.0?basic-mode=explicit</capability></capabilities>'

new "B.2.1.  Create New Data Resources (artist+json)"
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox/library -d '{"example-jukebox:artist":[{"name":"Foo Fighters"}]}')" 0 "HTTP/1.1 201 Created" "Location: http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters"

new "B.2.1.  Create New Data Resources (album+xml)"
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+xml' http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters -d '<album xmlns="http://example.com/ns/example-jukebox"><name>Wasting Light</name><year>2011</year></album>')" 0 "HTTP/1.1 201 Created" "Location: http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters/album=Wasting%20Light"

new "B.2.1.  Add Data Resources again (conflict - not in RFC)"
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+xml' http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters -d '<album xmlns="http://example.com/ns/example-jukebox"><name>Wasting Light</name><year>2011</year></album>')" 0 "HTTP/1.1 409 Conflict"

new "4.5. PUT replace content"
expectpart "$(curl -s -i -X PUT -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters/album=Wasting%20Light -d '{"example-jukebox:album":[{"name":"Wasting Light","genre":"example-jukebox:alternative","year":2011}]}')" 0 "HTTP/1.1 204 No Content"

new "4.5. PUT replace content (xml encoding)"
expectpart "$(curl -s -i -X PUT -H 'Content-Type: application/yang-data+xml' http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters/album=Wasting%20Light -d '<album xmlns="http://example.com/ns/example-jukebox" xmlns:jbox="http://example.com/ns/example-jukebox"><name>Wasting Light</name><genre>jbox:alternative</genre><year>2011</year></album>')" 0 "HTTP/1.1 204 No Content"

new "4.5. PUT create new identity"
expectpart "$(curl -s -i -X PUT -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -d '{"example-jukebox:album":[{"name":"London Calling","year":1979}]}')" 0 "HTTP/1.1 201 Created"

new "restconf DELETE whole datastore"
expectfn 'curl -s -X DELETE http://localhost/restconf/data' 0 ""

new "B.2.4.  Replace a Datastore Resource"
expectpart "$(curl -s -i -X PUT -H 'Content-Type: application/yang-data+xml' http://localhost/restconf/data -d '<data xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><jukebox xmlns="http://example.com/ns/example-jukebox"><library><artist><name>Foo Fighters</name><album><name>One by One</name><year>2012</year></album></artist><artist><name>Nick Cave and the Bad Seeds</name><album><name>Tender Prey</name><year>1988</year></album></artist></library></jukebox></data>')" 0 "HTTP/1.1 201 Created"

new "restconf DELETE whole datastore"
expectfn 'curl -s -X DELETE http://localhost/restconf/data' 0 ""

new 'B.3.4.  "insert" Parameter'
JSON="{\"example-jukebox:song\":[{\"index\":1,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='Rope']\"}]}"
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=first -d "$JSON")" 0 "HTTP/1.1 201 Created" 'Location: http://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One/song=1'

new 'B.3.4.  "insert" Parameter first (RFC example says after)'
JSON="{\"example-jukebox:song\":[{\"index\":0,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='Bridge Burning']\"}]}"
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=first -d "$JSON")" 0 "HTTP/1.1 201 Created" 'Location: http://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One/song=0'

new 'B.3.4.  "insert" Parameter check order'
RES="<playlist xmlns=\"http://example.com/ns/example-jukebox\"><name>Foo-One</name><song><index>0</index><id>/example-jukebox:jukebox/library/artist\[name='Foo Fighters'\]/album\[name='Wasting Light'\]/song\[name='Bridge Burning'\]</id></song><song><index>1</index><id>/example-jukebox:jukebox/library/artist\[name='Foo Fighters'\]/album\[name='Wasting Light'\]/song\[name='Rope'\]</id></song></playlist>"
expectpart "$(curl -s -i -X GET http://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One -H 'Accept: application/yang-data+xml')" 0 'HTTP/1.1 200 OK' "$RES"

new 'B.3.5.  "point" Parameter (before for more interesting order: 0,2,1)'
JSON="{\"example-jukebox:song\":[{\"index\":2,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='Bridge Burning']\"}]}"
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+json' -d "$JSON" http://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=before\&point=%2Fexample-jukebox%3Ajukebox%2Fplaylist%3DFoo-One%2Fsong%3D1 )" 0 "HTTP/1.1 201 Created" 'Location: http://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One/song=2'

new 'B.3.5.  "point" check order (0,2,1)'
RES="<playlist xmlns=\"http://example.com/ns/example-jukebox\"><name>Foo-One</name><song><index>0</index><id>/example-jukebox:jukebox/library/artist\[name='Foo Fighters'\]/album\[name='Wasting Light'\]/song\[name='Bridge Burning'\]</id></song><song><index>2</index><id>/example-jukebox:jukebox/library/artist\[name='Foo Fighters'\]/album\[name='Wasting Light'\]/song\[name='Bridge Burning'\]</id></song><song><index>1</index><id>/example-jukebox:jukebox/library/artist\[name='Foo Fighters'\]/album\[name='Wasting Light'\]/song\[name='Rope'\]</id></song></playlist>"
expectpart "$(curl -s -i -X GET http://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One -H 'Accept: application/yang-data+xml')" 0 'HTTP/1.1 200 OK' "$RES" 

new 'B.3.5.  "point" Parameter 3 after 2 (using PUT)'
JSON="{\"example-jukebox:song\":[{\"index\":3,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='Something else']\"}]}"
expectpart "$(curl -s -i -X PUT -H 'Content-Type: application/yang-data+json' -d "$JSON" http://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One/song=3?insert=after\&point=%2Fexample-jukebox%3Ajukebox%2Fplaylist%3DFoo-One%2Fsong%3D2 )" 0 "HTTP/1.1 201 Created"

new 'B.3.5.  "point" check order (0,2,3,1)'
RES="<playlist xmlns=\"http://example.com/ns/example-jukebox\"><name>Foo-One</name><song><index>0</index><id>/example-jukebox:jukebox/library/artist\[name='Foo Fighters'\]/album\[name='Wasting Light'\]/song\[name='Bridge Burning'\]</id></song><song><index>2</index><id>/example-jukebox:jukebox/library/artist\[name='Foo Fighters'\]/album\[name='Wasting Light'\]/song\[name='Bridge Burning'\]</id></song><song><index>3</index><id>/example-jukebox:jukebox/library/artist\[name='Foo Fighters'\]/album\[name='Wasting Light'\]/song\[name='Something else'\]</id></song><song><index>1</index><id>/example-jukebox:jukebox/library/artist\[name='Foo Fighters'\]/album\[name='Wasting Light'\]/song\[name='Rope'\]</id></song></playlist>"
expectpart "$(curl -s -i -X GET http://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One -H 'Accept: application/yang-data+xml')" 0 'HTTP/1.1 200 OK' "$RES"

new "restconf DELETE whole datastore"
expectfn 'curl -s -X DELETE http://localhost/restconf/data' 0 ""

new 'B.3.4.  "insert/point" leaf-list 3 (not in RFC)'
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data?insert=last -d '{"example-jukebox:extra":"3"}')" 0 "HTTP/1.1 201 Created" 'Location: http://localhost/restconf/data/example-jukebox:extra=3'

new 'B.3.4.  "insert/point" leaf-list 2 first'
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data?insert=first -d '{"example-jukebox:extra":"2"}')" 0 "HTTP/1.1 201 Created" 'Location: http://localhost/restconf/data/example-jukebox:extra=2'

new 'B.3.4.  "insert/point" leaf-list 1 last'
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data?insert=last -d '{"example-jukebox:extra":"1"}')" 0 "HTTP/1.1 201 Created" 'Location: http://localhost/restconf/data/example-jukebox:extra=1'

#new 'B.3.4.  "insert/point" move leaf-list 1 last'
#- restconf cannot move a leaf-list(list?) item
#expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data?insert=last -d '{"example-jukebox:extra":"1"}')" 0 "HTTP/1.1 201 Created" 'Location: http://localhost/restconf/data/example-jukebox:extra=1'

new 'B.3.5.  "insert/point" leaf-list check order (2,3,1)'
expectpart "$(curl -s -i -X GET http://localhost/restconf/data/example-jukebox:extra -H 'Accept: application/yang-data+xml')" 0 'HTTP/1.1 200 OK' '<extra xmlns="http://example.com/ns/example-jukebox">2</extra><extra xmlns="http://example.com/ns/example-jukebox">3</extra><extra xmlns="http://example.com/ns/example-jukebox">1</extra>'

new 'B.3.5.  "point" Parameter leaf-list 4 before 3'
expectpart "$(curl -s -i -X POST -H 'Content-Type: application/yang-data+json' -d '{"example-jukebox:extra":"4"}' http://localhost/restconf/data?insert=before\&point=%2Fexample-jukebox%3Aextra%3D3 )" 0 "HTTP/1.1 201 Created" 'Location: http://localhost/restconf/data/example-jukebox:extra=4'

new 'B.3.5.  "insert/point" leaf-list check order (2,4,3,1)'
expectpart "$(curl -s -i -X GET http://localhost/restconf/data/example-jukebox:extra -H 'Accept: application/yang-data+xml')" 0 'HTTP/1.1 200 OK' '<extra xmlns="http://example.com/ns/example-jukebox">2</extra><extra xmlns="http://example.com/ns/example-jukebox">4</extra><extra xmlns="http://example.com/ns/example-jukebox">3</extra><extra xmlns="http://example.com/ns/example-jukebox">1</extra>'

if false; then # NYI

new "B.2.2.  Detect Datastore Resource Entity-Tag Change"
new "B.2.3.  Edit a Datastore Resource"
new "B.2.5.  Edit a Data Resource"
new 'B.3.1.  "content" Parameter'
new 'B.3.2.  "depth" Parameter'
new 'B.3.3.  "fields" Parameter'
new 'B.3.6.  "filter" Parameter'
new 'B.3.7.  "start-time" Parameter'
new 'B.3.8.  "stop-time" Parameter'
new 'B.3.9.  "with-defaults" Parameter'

fi # NYI

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
