#!/usr/bin/env bash
# Restconf RFC8072 yang patch 
# XXX enable YANG_PACTH in include/clixon_custom.h to run this test
# Use nacm module in example/main/example_restconf.c hardcoded to
# andy:bar and wilma:bar

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Enable if YANG_PATCH
echo "...skipped: YANG_PATCH JSON NYI"
rm -rf $dir
if [ -z "${CLIXON_YANG_PATCH}" -a "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example
    
cfg=$dir/conf.xml
startupdb=$dir/startup_db
fjukebox=$dir/example-jukebox.yang
    
# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config user false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
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
      import iana-if-type {
        prefix ianaift;
      }
      import ietf-interfaces { 
	/* is in yang/optional which means clixon must be installed using --opt-yang-installdir */
	prefix if;
      }
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

# Modify several interfaces with a YANG patch, testing create, merge, and delete
REQ='{
  "ietf-yang-patch:yang-patch": {
    "patch-id": "alan-test-patch",
    "edit": [
      {
        "edit-id": "edit-1",
        "operation": "create",
        "target": "/interface=eth1",
        "value": {
          "interface": [
            { 
              "name": "eth1",
              "type": "iana-if-type:atm",
              "enabled": "false"
            }
          ]
        }
      },
      {
        "edit-id": "edit-2",
        "operation": "create",
        "target": "/interface=eth2",
        "value": {
          "interface": [
            {
              "name": "eth2",
              "type": "iana-if-type:atm",
              "enabled": "false"
            }
          ]
        }
      },
      {
        "edit-id": "edit-3",
        "operation": "create",
        "target": "/interface=eth4",
        "value": {
          "interface": [
            {
              "name": "eth4",
              "type": "iana-if-type:atm",
              "enabled": "false"
            }
          ]
        }
      },
      {
        "edit-id": "edit-4",
        "operation": "merge",
        "target": "/interface=eth2",
        "value": {
          "interface": [
            { 
              "enabled": "true"
            }
          ]
        }
      },
      {
        "edit-id": "edit-5",
        "operation": "delete",
        "target": "/interface=eth1"
      }
    ]
  }
}'
new "RFC 8072 YANG Patch JSON: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-patch+json' -H 'Accept: application/yang-patch+json' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces -d "$REQ")" 0 "HTTP/$HVER 204"
#
# Create artist in jukebox example
REQ='{"example-jukebox:artist":[{"name":"Foo Fighters"}]}'
new "RFC 8072 YANG Patch JSON jukebox example 1: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library -d "$REQ")" 0 "HTTP/$HVER 201"

# Create album in jukebox example
REQ='<album xmlns="http://example.com/ns/example-jukebox"><name>Wasting Light</name><year>2011</year></album>'
new "RFC 8072 YANG Patch JSON jukebox example 2: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters -d "$REQ")" 0 "HTTP/$HVER 201"

# Add fields to album in jukebox example
REQ='{"example-jukebox:album":[{"name":"Wasting Light","genre":"example-jukebox:alternative","year":2011}]}'
new "RFC 8072 YANG Patch JSON jukebox example 3: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters/album=Wasting%20Light -d "$REQ")" 0 "HTTP/$HVER 204"

# Uncomment to get info about album in jukebox example
#new "RFC 8072 YANG Patch jukebox example get 2: Error."
#expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library)" 0 "HTTP/$HVER 201 OK"

# Add songs to playlist in jukebox example
REQ="{\"example-jukebox:song\":[{\"index\":1,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='Rope']\"}]}"
new "RFC 8072 YANG Patch JSON jukebox example 4: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=first -d "$REQ")" 0 "HTTP/$HVER 201"

# Add song at end of playlist
REQ="{\"example-jukebox:song\":[{\"index\":2,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='Bridge Burning']\"}]}"
new "RFC 8072 YANG Patch JSON jukebox example 5: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=last -d "$REQ")" 0 "HTTP/$HVER 201"

# Add song at end of playlist
REQ="{\"example-jukebox:song\":[{\"index\":4,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='Still More Rope']\"}]}"
new "RFC 8072 YANG Patch JSON jukebox example 6: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=last -d "$REQ")" 0 "HTTP/$HVER 201"

# Add song at end of playlist
REQ="{\"example-jukebox:song\":[{\"index\":3,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='More Rope']\"}]}"
new "RFC 8072 YANG Patch JSON jukebox example 7: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=last -d "$REQ")" 0 "HTTP/$HVER 201"

# Run YANG patch on the playlist, testing "insert after" and "insert before"
REQ='{
  "ietf-yang-patch:yang-patch": {
    "patch-id": "alan-test-patch-jukebox",
    "edit": [
      {
        "edit-id": "edit-2",
        "operation": "insert",
        "target": "/song=5",
        "point": "/song=1",
        "where" : "after",
        "value": {
          "example-jukebox:song": [
            {
              "index": 5,
              "id" : "Rope Galore"
            }
          ]
        }
      },
      {
        "edit-id": "edit-3",
        "operation": "insert",
        "target": "/song=6",
        "point": "/song=4",
        "where" : "before",
        "value": {
          "example-jukebox:song": [
            {
              "index": 6,
              "id" : "How Much Rope Does a Man Need"
            }
          ]
        }
      },
      {
        "edit-id": "edit-2",
        "operation": "insert",
        "target": "/song=24",
        "point": "/song=6",
        "where" : "after",
        "value": {
          "example-jukebox:song": [
            {
              "index": 24,
              "id" : "The twenty fourth song"
            }
          ]
        }
      }
    ]
  }
}'
new "RFC 8072 YANG Patch JSON jukebox example: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-patch+json' -H 'Accept: application/yang-patch+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One -d "$REQ")" 0 "HTTP/$HVER 201"

# Uncomment to get info about playlist in jukebox example
#new "RFC 8072 YANG Patch jukebox example get : Error."
#expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One)" 0 "HTTP/$HVER 201 OK"

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

# Set by restconf_config
unset RESTCONFIG

rm -rf $dir

new "endtest"
endtest
