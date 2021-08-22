#!/usr/bin/env bash
# List pagination tests according to draft-wwlh-netconf-list-pagination-00
# Backlog items:
# 1. "remaining" annotation RFC 7952
# 2. pattern '.*[\n].*' { modifier invert-match;
# XXX: augment Netconf GET instead, not RPC

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fexample=$dir/example-social.yang
fstate=$dir/mystate.xml

# Common example-module spec (fexample must be set)
. ./example_social.sh

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

# Validate internal state xml
: ${validatexml:=false}

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_FORMAT>json</CLICON_XMLDB_FORMAT>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_VALIDATE_STATE_XML>$validatexml</CLICON_VALIDATE_STATE_XML>
  $RESTCONFIG
</clixon-config>
EOF

# See draft-wwlh-netconf-list-pagination-00 A.2 (except stats and audit-log)
cat <<'EOF' > $dir/startup_db
{"config":
   {
     "example-social:members": {
       "member": [
         {
           "member-id": "alice",
           "email-address": "alice@example.com",
           "password": "$0$1543",
           "avatar": "BASE64VALUE=",
           "tagline": "Every day is a new day",
           "privacy-settings": {
             "hide-network": "false",
             "post-visibility": "public"
           },
           "following": ["bob", "eric", "lin"],
           "posts": {
             "post": [
               {
                 "timestamp": "2020-07-08T13:12:45Z",
                 "title": "My first post",
                 "body": "Hiya all!"
               },
               {
                 "timestamp": "2020-07-09T01:32:23Z",
                 "title": "Sleepy...",
                 "body": "Catch y'all tomorrow."
               }
             ]
           },
           "favorites": {
             "uint8-numbers": [17, 13, 11, 7, 5, 3],
             "int8-numbers": [-5, -3, -1, 1, 3, 5]
           }
         },
         {
           "member-id": "bob",
           "email-address": "bob@example.com",
           "password": "$0$1543",
           "avatar": "BASE64VALUE=",
           "tagline": "Here and now, like never before.",
           "posts": {
             "post": [
               {
                 "timestamp": "2020-08-14T03:32:25Z",
                 "body": "Just got in."
               },
               {
                 "timestamp": "2020-08-14T03:33:55Z",
                 "body": "What's new?"
               },
               {
                 "timestamp": "2020-08-14T03:34:30Z",
                 "body": "I'm bored..."
               }
             ]
           },
           "favorites": {
             "decimal64-numbers": ["3.14159", "2.71828"]
           }
         },
         {
           "member-id": "eric",
           "email-address": "eric@example.com",
           "password": "$0$1543",
           "avatar": "BASE64VALUE=",
           "tagline": "Go to bed with dreams; wake up with a purpose.",
           "following": ["alice"],
           "posts": {
             "post": [
               {
                 "timestamp": "2020-09-17T18:02:04Z",
                 "title": "Son, brother, husband, father",
                 "body": "What's your story?"
               }
             ]
           },
           "favorites": {
             "bits": ["two", "one", "zero"]
           }
         },
         {
           "member-id": "lin",
           "email-address": "lin@example.com",
           "password": "$0$1543",
           "privacy-settings": {
             "hide-network": "true",
             "post-visibility": "followers-only"
           },
           "following": ["joe", "eric", "alice"]
         },
         {
           "member-id": "joe",
           "email-address": "joe@example.com",
           "password": "$0$1543",
           "avatar": "BASE64VALUE=",
           "tagline": "Greatness is measured by courage and heart.",
           "privacy-settings": {
             "post-visibility": "unlisted"
           },
           "following": ["bob"],
           "posts": {
             "post": [
               {
                 "timestamp": "2020-10-17T18:02:04Z",
                 "body": "What's your status?"
               }
             ]
           }
         }
       ]
     }
   }
}
EOF

# See draft-wwlh-netconf-list-pagination-00 A.2 (only stats and audit-log)
cat<<EOF > $fstate
<members xmlns="http://example.com/ns/example-social">
   <member>
      <member-id>alice</member-id>
      <stats>
          <joined>2020-07-08T12:38:32Z</joined>
	  <membership-level>admin</membership-level>
          <last-activity>2021-04-01T02:51:11Z</last-activity>
      </stats>
   </member>
   <member>
      <member-id>bob</member-id>
      <stats>
          <joined>2020-08-14T03:30:00Z</joined>
	  <membership-level>standard</membership-level>
          <last-activity>2020-08-14T03:34:30Z</last-activity>
      </stats>
   </member>
   <member>
      <member-id>eric</member-id>
      <stats>
          <joined>2020-09-17T19:38:32Z</joined>
	  <membership-level>pro</membership-level>
          <last-activity>2020-09-17T18:02:04Z</last-activity>
      </stats>
   </member>
   <member>
      <member-id>lin</member-id>
      <stats>
          <joined>2020-07-09T12:38:32Z</joined>
	  <membership-level>standard</membership-level>
          <last-activity>2021-04-01T02:51:11Z</last-activity>
      </stats>
   </member>
   <member>
      <member-id>joe</member-id>
      <stats>
          <joined>2020-10-08T12:38:32Z</joined>
	  <membership-level>pro</membership-level>
          <last-activity>2021-04-01T02:51:11Z</last-activity>
      </stats>
   </member>
</members>
<audit-logs xmlns="http://example.com/ns/example-social">
   <audit-log>
      <timestamp>": "2020-10-11T06:47:59Z",</timestamp>
           <member-id>alice</member-id>
           <source-ip>192.168.0.92</source-ip>
           <request>POST /groups/group/2043</request>
           <outcome>true</outcome>
   </audit-log>
   <audit-log>
           <timestamp>2020-11-01T15:22:01Z</timestamp>
           <member-id>bob</member-id>
           <source-ip>192.168.2.16</source-ip>
           <request>POST /groups/group/123</request>
           <outcome>false</outcome>
   </audit-log>
   <audit-log>
           <timestamp>2020-12-12T21:00:28Z</timestamp>
           <member-id>eric</member-id>
           <source-ip>192.168.254.1</source-ip>
           <request>POST /groups/group/10</request>
           <outcome>true</outcome>
   </audit-log>
   <audit-log>
           <timestamp>2021-01-03T06:47:59Z</timestamp>
           <member-id>alice</member-id>
           <source-ip>192.168.0.92</source-ip>
           <request>POST /groups/group/333</request>
           <outcome>true</outcome>
   </audit-log>
   <audit-log>
           <timestamp>2021-01-21T10:00:00Z</timestamp>
           <member-id>bob</member-id>
           <source-ip>192.168.2.16</source-ip>
           <request>POST /groups/group/42</request>
           <outcome>true</outcome>
   </audit-log>
   <audit-log>
           <timestamp>2020-02-07T09:06:21Z</timestamp>
           <member-id>alice</member-id>
           <source-ip>192.168.0.92</source-ip>
           <request>POST /groups/group/1202</request>
           <outcome>true</outcome>
   </audit-log>
   <audit-log>
           <timestamp>2020-02-28T02:48:11Z</timestamp>
           <member-id>bob</member-id>
           <source-ip>192.168.2.16</source-ip>
           <request>POST /groups/group/345</request>
           <outcome>true</outcome>
   </audit-log>
</audit-logs>
EOF

# Run limit-only test with netconf, restconf+xml and restconf+json
# Args:
# 1. limit
# 2. remaining
# 3. list XXX remaining
function testlimit()
{
    limit=$1
    remaining=$2

    # "clixon get"
    new "clixon limit=$limit NETCONF get-config"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/es:members/es:member[es:member-id='alice']/es:favorites/es:uint8-numbers\" xmlns:es=\"http://example.com/ns/example-social\"/><list-pagination xmlns=\"http://clicon.org/clixon-netconf-list-pagination\">true</list-pagination><limit xmlns=\"http://clicon.org/clixon-netconf-list-pagination\">$limit</limit></get-config></rpc>]]>]]>" "<rpc-reply $DEFAULTNS><data><members xmlns=\"http://example.com/ns/example-social\"><member><member-id>alice</member-id><privacy-settings><post-visibility>public</post-visibility></privacy-settings><favorites><uint8-numbers cp:remaining=\"$remaining\" xmlns:cp=\"http://clicon.org/clixon-netconf-list-pagination\">17</uint8-numbers></favorites></member></members></data></rpc-reply>]]>]]>$"

    new "clixon limit=$limit NETCONF get"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member[es:member-id='alice']/es:favorites/es:uint8-numbers\" xmlns:es=\"http://example.com/ns/example-social\"/><list-pagination xmlns=\"http://clicon.org/clixon-netconf-list-pagination\">true</list-pagination><limit xmlns=\"http://clicon.org/clixon-netconf-list-pagination\">$limit</limit></get></rpc>]]>]]>" "<rpc-reply $DEFAULTNS><data><members xmlns=\"http://example.com/ns/example-social\"><member><member-id>alice</member-id><privacy-settings><post-visibility>public</post-visibility></privacy-settings><favorites><uint8-numbers cp:remaining=\"$remaining\" xmlns:cp=\"http://clicon.org/clixon-netconf-list-pagination\">17</uint8-numbers></favorites></member></members></data></rpc-reply>]]>]]>$"

    # "old: ietf"
    new "ietf limit=$limit NETCONF"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-pageable-list xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-list-pagination\"><datastore xmlns:ds=\"urn:ietf:params:xml:ns:yang:ietf-datastores\">ds:running</datastore><list-target xmlns:es=\"http://example.com/ns/example-social\">/es:members/es:member[es:member-id='alice']/es:favorites/es:uint8-numbers</list-target><limit>$limit</limit></get-pageable-list></rpc>]]>]]>" "<rpc-reply $DEFAULTNS><pageable-list xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-list-pagination\"><uint8-numbers xmlns=\"http://example.com/ns/example-social\" ycoll:remaining=\"$remaining\" xmlns:ycoll=\"urn:ietf:params:xml:ns:yang:ietf-netconf-list-pagination\">17</uint8-numbers></pageable-list></rpc-reply>]]>]]>$"

    new "limit=$limit Parameter RESTCONF xml"
    expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-collection+xml" $RCPROTO://localhost/restconf/data/example-social:members/member=alice/favorites/uint8-numbers?limit=$limit)" 0 "HTTP/$HVER 200" "Content-Type: application/yang-collection+xml" "<pageable-list xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-list-pagination\"><uint8-numbers xmlns=\"http://example.com/ns/example-social\" ycoll:remaining=\"$remaining\" xmlns:ycoll=\"urn:ietf:params:xml:ns:yang:ietf-netconf-list-pagination\">17</uint8-numbers></pageable-list>"

    # XXX [17]
    new "limit=$limit Parameter RESTCONF json"
    expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-collection+json" $RCPROTO://localhost/restconf/data/example-social:members/member=alice/favorites/uint8-numbers?limit=$limit)" 0 "HTTP/$HVER 200" "Content-Type: application/yang-collection+json" "{\"pageable-list\":{\"example-social:uint8-numbers\":17,\"@example-social:uint8-numbers\": \[{\"ietf-netconf-list-pagination:remaining\": $remaining}\]}}"
}

new "test params: -f $cfg -s startup -- -sS $fstate"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure

    new "start backend -s startup -f $cfg -- -sS $fstate"
    start_backend -s startup -f $cfg -- -sS $fstate
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

new "A.3.1.1. limit=1"
testlimit 1 5 "[17]"

#new "A.3.1.2. limit=2"
#testlimit 2 4 "[17 13]"

# CLI
# XXX This relies on a very specific clispec command: need a more generic test
#new "cli show"
#expectpart "$($clixon_cli -1 -f $cfg -l o show pagination)" 0 "<skill xmlns=\"http://example.com/ns/example-module\">" "<name>Conflict Resolution</name>" "<rank>93</rank>" "<name>Management</name>" "<rank>23</rank>" --not-- "<name>Organization</name>" "<rank>44</rank></skill>"

# draft-wwlh-netconf-list-pagination-rc-00.txt
#new "A.1. 'count' Parameter RESTCONF"
#expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-collection+xml" $RCPROTO://localhost/restconf/data/example-module:get-list-pagination/library/artist=Foo%20Fighters/album/?count=2)" 0  "HTTP/1.1 200 OK" "application/yang-collection+xml" '<collection xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-collection"><album xmlns="http://example.com/ns/example-jukebox"><name>Crime and Punishment</name><year>1995</year></album><album xmlns="http://example.com/ns/example-jukebox"><name>One by One</name><year>2002</year></album></collection>'

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

unset RESTCONFIG
unset validatexml

rm -rf $dir

new "endtest"
endtest
