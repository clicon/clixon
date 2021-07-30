#!/usr/bin/env bash
# Restconf RFC8072 yang patch 
# XXX enable YANG_PACTH in include/clixon_custom.h to run this test
# Use nacm module in example/main/example_restconf.c hardcoded to
# andy:bar and wilma:bar

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

echo "...skipped: YANG_PATCH NYI"
if [ "$s" = $0 ]; then exit 0; else return 0; fi
    
APPNAME=example
    
cfg=$dir/conf.xml
startupdb=$dir/startup_db
fjukebox=$dir/example-jukebox.yang
    
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

# RFC 8072 A.1.1 
REQ='<yang-patch xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-patch">
        <patch-id>add-songs-patch</patch-id>
        <edit>
          <edit-id>edit1</edit-id>
          <operation>create</operation>
          <target>/song=Bridge%20Burning</target>
          <value>
            <song xmlns="http://example.com/ns/example-jukebox">
              <name>Bridge Burning</name>
              <location>/media/bridge_burning.mp3</location>
              <format>MP3</format>
              <length>288</length>
            </song>
          </value>
        </edit>
        <edit>
          <edit-id>edit2</edit-id>
          <operation>create</operation>
          <target>/song=Rope</target>
          <value>
            <song xmlns="http://example.com/ns/example-jukebox">
              <name>Rope</name>
              <location>/media/rope.mp3</location>
              <format>MP3</format>
              <length>259</length>
            </song>
          </value>
        </edit>
        <edit>
          <edit-id>edit3</edit-id>
          <operation>create</operation>
          <target>/song=Dear%20Rosemary</target>
          <value>
            <song xmlns="http://example.com/ns/example-jukebox">
              <name>Dear Rosemary</name>
              <location>/media/dear_rosemary.mp3</location>
              <format>MP3</format>
              <length>269</length>
            </song>
          </value>
        </edit>
      </yang-patch>'

new "RFC 8072 A.1.1 Add resources: Error."
expectpart "$(curl -u andy:bar $CURLOPTS -X PATCH -H 'Content-Type: application/yang-patch+xml' -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters/album=Wasting%20Light -d "$REQ")" 0 "HTTP/$HVER 409"


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
