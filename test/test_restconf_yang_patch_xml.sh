#!/usr/bin/env bash
# Restconf RFC8072 yang patch 
# XXX enable YANG_PACTH in include/clixon_custom.h to run this test
# Use nacm module in example/main/example_restconf.c hardcoded to
# andy:bar and wilma:bar

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

echo "...skipped: YANG_PATCH XML NYI"
if [ "$s" = $0 ]; then exit 0; else return 0; fi
    
APPNAME=example
    
cfg=$dir/conf.xml
startupdb=$dir/startup_db
fjukebox=$dir/example-jukebox.yang
fyangpatch=$dir/ietf-yang-patch.yang
finterfaces=$dir/ietf-interfaces.yang
fexample=$dir/clixon-example.yang
    
# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config user false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
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

# Yang Patch spec (fyangpatch must be set)
. ./yang-patch.sh

# Interfaces spec (finterfaces must be set)
. ./interfaces.sh

# clixon example spec (fexample must be set)
. ./example.sh

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
REQ='<ietf-yang-patch:yang-patch>
    <patch-id>test-patch-xml</patch-id>
      <edit>
        <edit-id>edit-1</edit-id>
        <operation>create</operation>
        <target>/interface=eth1</target>
        <value>
          <interface>
              <name>eth1</name>
              <type>clixon-example:eth</type>
              <enabled>false</false>
          </interface>
        </value>
      </edit>
      <edit>
        <edit-id>edit-2</edit-id>
        <operation>create</operation>
        <target>/interface=eth2</target>
        <value>
          <interface>
              <name>eth2</name>
              <type>clixon-example:eth</type>
              <enabled>false</false>
          </interface>
        </value>
      </edit>
      <edit>
        <edit-id>edit-3</edit-id>
        <operation>create</operation>
        <target>/interface=eth4</target>
        <value>
          <interface>
              <name>eth4</name>
              <type>clixon-example:eth</type>
              <enabled>false</false>
          </interface>
        </value>
      </edit>
      <edit>
        <edit-id>edit-4</edit-id>
        <operation>merge</operation>
        <target>/interface=eth2</target>
        <value>
          <interface>
              <enabled>true</false>
          </interface>
        </value>
      </edit>
      <edit>
        <edit-id>edit-5</edit-id>
        <operation>delete</operation>
        <target>/interface=eth1</target>
      </edit>
  </ietf-yang-patch:yang-patch>'
new "RFC 8072 YANG Patch XML Media: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-patch+xml' -H 'Accept: application/yang-patch+xml' $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces -d "$REQ")" 0 "HTTP/$HVER 204 No Content"
#
# Create artist in jukebox example
REQ='{"example-jukebox:artist":[{"name":"Foo Fighters"}]}'
new "RFC 8072 YANG Patch jukebox example 1: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library -d "$REQ")" 0 "HTTP/$HVER 201 Created"

# Create album in jukebox example
REQ='<album xmlns="http://example.com/ns/example-jukebox"><name>Wasting Light</name><year>2011</year></album>'
new "RFC 8072 YANG Patch jukebox example 2: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters -d "$REQ")" 0 "HTTP/$HVER 201 Created"

# Add fields to album in jukebox example
REQ='{"example-jukebox:album":[{"name":"Wasting Light","genre":"example-jukebox:alternative","year":2011}]}'
new "RFC 8072 YANG Patch jukebox example 3: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters/album=Wasting%20Light -d "$REQ")" 0 "HTTP/$HVER 204 No Content"

# Uncomment to get info about album in jukebox example
#new "RFC 8072 YANG Patch jukebox example get 2: Error."
#expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library)" 0 "HTTP/$HVER 201 OK"

# Add songs to playlist in jukebox example
REQ="{\"example-jukebox:song\":[{\"index\":1,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='Rope']\"}]}"
new "RFC 8072 YANG Patch jukebox example 4: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=first -d "$REQ")" 0 "HTTP/$HVER 201 Created"

# Add song at end of playlist
REQ="{\"example-jukebox:song\":[{\"index\":2,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='Bridge Burning']\"}]}"
new "RFC 8072 YANG Patch jukebox example 5: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=last -d "$REQ")" 0 "HTTP/$HVER 201 Created"

# Add song at end of playlist
REQ="{\"example-jukebox:song\":[{\"index\":4,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='Still More Rope']\"}]}"
new "RFC 8072 YANG Patch jukebox example 6: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=last -d "$REQ")" 0 "HTTP/$HVER 201 Created"

# Add song at end of playlist
REQ="{\"example-jukebox:song\":[{\"index\":3,\"id\":\"/example-jukebox:jukebox/library/artist[name='Foo Fighters']/album[name='Wasting Light']/song[name='More Rope']\"}]}"
new "RFC 8072 YANG Patch jukebox example 7: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One?insert=last -d "$REQ")" 0 "HTTP/$HVER 201 Created"

# Run YANG patch on the playlist, testing "insert after" and "insert before"
REQ='<ietf-yang-patch:yang-patch>
    <patch-id>test-patch-jukebox</patch-id>
    <edit>
        <edit-id>edit-1</edit-id>
        <operation>insert</operation>
        <target>/song=5</target>
        <point>/song=1</point>
        <where>after</where>
        <value>
          <example-jukebox:song>
              <index>5</index>
              <id>Rope Galore</id>
          </example-jukebox:song>
        </value>
    </edit>
    <edit>
        <edit-id>edit-2</edit-id>
        <operation>insert</operation>
        <target>/song=6</target>
        <point>/song=4</point>
        <where>before</where>
        <value>
          <example-jukebox:song>
              <index>6</index>
              <id>How Much Rope Does a Man Need</id>
          </example-jukebox:song>
    </edit>
    <edit>
        <edit-id>edit-3</edit-id>
        <operation>insert</operation>
        <target>/song=24</target>
        <point>/song=6</point>
        <where>before</where>
        <value>
          <example-jukebox:song>
              <index>24</index>
              <id>The twenty-fourth song</id>
          </example-jukebox:song>
    </edit>
  </ietf-yang-patch:yang-patch>'
new "RFC 8072 YANG Patch XML jukebox example: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-patch+json' -H 'Accept: application/yang-patch+json' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/playlist=Foo-One -d "$REQ")" 0 "HTTP/$HVER 201 Created"

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
