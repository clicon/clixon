#!/usr/bin/env bash
# Restconf RFC8040 plain patch Sec 4.6 / 4.6.1
# Use nacm module in example/main/example_restconf.c hardcoded to
# andy:bar and wilma:bar

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
startupdb=$dir/startup_db
fjukebox=$dir/example-jukebox.yang

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config user false)
if [ $? -ne 0 ]; then
    err1 "Error when generating certs"
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
  $RESTCONFIG
</clixon-config>
EOF

NACM0="<nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\">
     <enable-nacm>true</enable-nacm>
     <read-default>deny</read-default>
     <write-default>deny</write-default>
     <exec-default>permit</exec-default>
   <groups>
       <group>
         <name>admin</name>
         <user-name>andy</user-name>
       </group>
       <group>
         <name>limited</name>
         <user-name>wilma</user-name>
       </group>
   </groups>
   <rule-list>
       <name>admin</name>
       <group>admin</group>
       <rule>
         <name>permit-all</name>
         <module-name>*</module-name>
         <access-operations>*</access-operations>
         <action>permit</action>
         <comment>
             Allow the 'admin' group complete access to all operations and data.
         </comment>
       </rule>
   </rule-list>
   <rule-list>
       <name>limited</name>
       <group>limited</group>
       <rule>
         <name>limit-jukebox</name>
         <module-name>jukebox-example</module-name>
         <access-operations>read create delete</access-operations>
         <action>deny</action>
       </rule>
   </rule-list>
 </nacm>
"

cat<<EOF > $startupdb
<${DATASTORE_TOP}>
   $NACM0
</${DATASTORE_TOP}>
EOF

# An extra testmodule that includes nacm
cat <<EOF > $dir/example-system.yang
   module example-system {
      namespace "http://example.com/ns/example-system";
      prefix "ex";
      import ietf-netconf-acm {
        prefix nacm;
      }
      container system {
        leaf enable-jukebox-streaming {
          type boolean;
        }
        leaf extraleaf {
          type string;
        }
      }
   }
EOF

# Common Jukebox spec (fjukebox must be set)
. ./jukebox.sh

new "test params: -s startup -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend # to be sure

    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
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

# also in test_restconf.sh
new "MUST support the PATCH method for a plain patch" 
expectpart "$(curl -u andy:bar $CURLOPTS -X OPTIONS $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 200" "Allow: OPTIONS,HEAD,GET,POST,PUT,PATCH,DELETE" "Accept-Patch: application/yang-data+xml,application/yang-data+json"

new "If the target resource instance does not exist, the server MUST NOT create it."
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox -d '{"example-jukebox:jukebox":null}')" 0 "HTTP/$HVER 409" "If the target resource instance does not exist, the server MUST NOT create it"

new "Create it with PUT instead"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox -d '{"example-jukebox:jukebox":null}')" 0 "HTTP/$HVER 201"

new "THEN change it with PATCH"
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox -d '{"example-jukebox:jukebox":{"library":{"artist":{"name":"Clash"}}}}')" 0 "HTTP/$HVER 204"

new "Check content (json)"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-jukebox:jukebox -H 'Accept: application/yang-data+json')" 0 "HTTP/$HVER 200" '{"example-jukebox:jukebox":{"library":{"artist":\[{"name":"Clash"}\]}}}'

new "Check content (xml)"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-jukebox:jukebox -H 'Accept: application/yang-data+xml')" 0 "HTTP/$HVER 200" '<jukebox xmlns="http://example.com/ns/example-jukebox"><library><artist><name>Clash</name></artist></library></jukebox>'

new 'If the user is not authorized, "403 Forbidden" SHOULD be returned.'
expectpart "$(curl -u wilma:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash -d '{"example-jukebox:artist":{"name":"Clash","album":{"name":"London Calling"}}}')" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new 'user is authorized'
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash -d '{"example-jukebox:artist":{"name":"Clash","album":{"name":"London Calling"}}}')" 0 "HTTP/$HVER 204"

# Kill old
if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

# Restart
cat<<EOF > $startupdb
<${DATASTORE_TOP}>
   $NACM0
</${DATASTORE_TOP}>
EOF
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend # to be sure
    
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
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

# 4.6.1.  Plain Patch
new "Create album London Calling with PUT"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -d '{"example-jukebox:album":{"name":"London Calling"}}')" 0 "HTTP/$HVER 201"

new "The message-body for a plain patch MUST be present"
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Beatles -d '')" 0 "HTTP/$HVER 400" "The message-body MUST contain exactly one instance of the expected data resource"

# Plain patch can be used to create or update, but not delete, a child
# resource within the target resource.
new "Create a child resource (genre and year)"
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH  -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -d '{"example-jukebox:album":{"name":"London Calling","genre":"example-jukebox:rock","year":"2129"}}')" 0 "HTTP/$HVER 204"

new "Update a child resource (year)"
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH  -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -d '{"example-jukebox:album":{"name":"London Calling","year":"1979"}}')" 0 "HTTP/$HVER 204"

new "Check content xml"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -H 'Accept: application/yang-data+xml')" 0 "HTTP/$HVER 200" '<album xmlns="http://example.com/ns/example-jukebox"><name>London Calling</name><genre>rock</genre><year>1979</year></album>'

new "Check content json"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -H 'Accept: application/yang-data+json')" 0 "HTTP/$HVER 200" '{"example-jukebox:album":\[{"name":"London Calling","genre":"rock","year":1979}\]}'

new "The message-body MUST be represented by the media type application/yang-data+xml (or +json ^)"
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -d '<album xmlns="http://example.com/ns/example-jukebox"><name>London Calling</name><genre>jazz</genre></album>')" 0 "HTTP/$HVER 204"

new "Check content (xml)"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-jukebox:jukebox -H 'Accept: application/yang-data+xml')" 0 "HTTP/$HVER 200" '<jukebox xmlns="http://example.com/ns/example-jukebox"><library><artist><name>Clash</name><album><name>London Calling</name><genre>jazz</genre><year>1979</year></album></artist></library></jukebox>'

if false; then # It is being implemented
new "not implemented media type"
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-patch+xml' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -d '<album xmlns="http://example.com/ns/example-jukebox"><name>London Calling</name><genre>jazz</genre></album>')" 0 "HTTP/$HVER 501"
fi

new "wrong media type"
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: text/html' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -d '<album xmlns="http://example.com/ns/example-jukebox"><name>London Calling</name><genre>jazz</genre></album>')" 0 "HTTP/$HVER 415"

# If the target resource represents a YANG leaf-list, then the PATCH
# method MUST NOT change the value of the leaf-list instance.
#      leaf-list extra{
new "Create leaf-list a"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:extra=a -d '{"example-jukebox:extra":"a"}')" 0 "HTTP/$HVER 201"

new "Create leaf-list b"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:extra=b -d '{"example-jukebox:extra":"b"}')" 0 "HTTP/$HVER 201"

new "Check content"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-jukebox:extra -H 'Accept: application/yang-data+json')" 0 "HTTP/$HVER 200" '{"example-jukebox:extra":\["a","b"\]}'

new "MUST NOT change the value of the leaf-list instance"
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:extra=a -d '{"example-jukebox:extra":"b"}')" 0 "HTTP/$HVER 412"

# If the target resource represents a YANG list instance, then the key
# leaf values, in message-body representation, MUST be the same as the
# key leaf values in the request URI.  The PATCH method MUST NOT be
# used to change the key leaf values for a data resource instance.

new "The key leaf values MUST be the same as the key leaf values in the request"
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH  -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Clash/album=London%20Calling -d '{"example-jukebox:album":{"name":"The Clash"}}')" 0 "HTTP/$HVER 412"

new "PATCH on root resource extra c" # merge extra/c
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH  -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data -d '{"ietf-restconf:data":{"example-jukebox:extra":"c"}}')" 0 "HTTP/$HVER 204"

new "GET check" # XXX: "data" should probably be namespaced?
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data?content=config -H 'Accept: application/yang-data+xml')" 0 "HTTP/$HVER 200" '<extra xmlns="http://example.com/ns/example-jukebox">c</extra>' "<data $DEFAULTONLY>"

new "Add empty leaf"
expectpart "$(curl -u andy:bar $CURLOPTS -X POST $RCPROTO://localhost/restconf/data -H 'Content-Type: application/yang-data+json' -d '{"example-system:system":{"extraleaf":""}}')" 0 "HTTP/$HVER 201"

new "Add entry with PATCH"
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH $RCPROTO://localhost/restconf/data/example-system:system -H 'Content-Type: application/yang-data+json' -d '{"example-system:system":{"extraleaf":"something"}}')" 0 "HTTP/$HVER 204"

new "GET check"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-system:system -H 'Accept: application/yang-data+xml')" 0 "HTTP/$HVER 200" '<system xmlns="http://example.com/ns/example-system"><extraleaf>something</extraleaf></system>'


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
