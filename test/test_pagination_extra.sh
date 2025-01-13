#!/usr/bin/env bash
# List pagination tests according to draft-ietf-netconf-list-pagination-04
# sort-by and where in Appendix A.3.5
# Only NETCONF, see more extensive testng in _draft test

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fexample=$dir/example-social.yang
fstate=$dir/mystate.xml

# Common example-module spec (fexample must be set)
. ./example_social.sh

# Validate internal state xml
: ${validatexml:=false}

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_FORMAT>json</CLICON_XMLDB_FORMAT>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_VALIDATE_STATE_XML>$validatexml</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

# See draft-netconf-list-pagination-04.txt A.2 (except stats and audit-log)
cat <<'EOF' > $dir/startup_db
{"config":
   {
     "example-social:members": {
       "member": [
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
           "member-id": "alice",
           "email-address": "alice@example.com",
           "password": "$0$1543",
           "avatar": "BASE64VALUE=",
           "tagline": "Every day is a new day",
           "privacy-settings": {
             "hide-network": false,
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
           "member-id": "lin",
           "email-address": "lin@example.com",
           "password": "$0$1543",
           "privacy-settings": {
             "hide-network": true,
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

# See draft-netconf-list-pagination-04.txt A.2 (only stats and audit-log)
cat<<EOF > $fstate
<members xmlns="https://example.com/ns/example-social">
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
      <member-id>alice</member-id>
      <stats>
          <joined>2020-07-08T12:38:32Z</joined>
          <membership-level>admin</membership-level>
          <last-activity>2021-04-01T02:51:11Z</last-activity>
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
EOF

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

new "A.3.4.1.  direction=forwards"
# 17, 13, 11, 7, 5, 3]
# Confusing: forwards means dont change order
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member[es:member-id='alice']/es:favorites/es:uint8-numbers\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><direction>forwards</direction></list-pagination></get></rpc>" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>alice</member-id><favorites><uint8-numbers>17</uint8-numbers><uint8-numbers>13</uint8-numbers><uint8-numbers>11</uint8-numbers><uint8-numbers>7</uint8-numbers><uint8-numbers>5</uint8-numbers><uint8-numbers>3</uint8-numbers></favorites></member></members></data></rpc-reply>"

new "A.3.4.2.  direction=backwards"
# 3, 5, 7, 11, 13, 17]
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member[es:member-id='alice']/es:favorites/es:uint8-numbers\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><direction>backwards</direction></list-pagination></get></rpc>" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>alice</member-id><favorites><uint8-numbers>3</uint8-numbers><uint8-numbers>5</uint8-numbers><uint8-numbers>7</uint8-numbers><uint8-numbers>11</uint8-numbers><uint8-numbers>13</uint8-numbers><uint8-numbers>17</uint8-numbers></favorites></member></members></data></rpc-reply>"

new "A.3.5.1.1.  sort-by type is a leaf-list"
# 3,5,7,11,13,17
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member[es:member-id='alice']/es:favorites/es:uint8-numbers\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><sort-by>.</sort-by></list-pagination></get></rpc>" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>alice</member-id><favorites><uint8-numbers>3</uint8-numbers><uint8-numbers>5</uint8-numbers><uint8-numbers>7</uint8-numbers><uint8-numbers>11</uint8-numbers><uint8-numbers>13</uint8-numbers><uint8-numbers>17</uint8-numbers></favorites></member></members></data></rpc-reply>"

new "A.3.5.1.2.  sort-by type is a list and sort-by node is a direct descendent"
# alice, bob, eric, joe, lin
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><sort-by>member-id</sort-by></list-pagination></get></rpc>" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>alice</member-id>.*<member-id>bob</member-id>.*<member-id>eric</member-id>.*<member-id>joe</member-id>.*<member-id>lin</member-id>"

new "A.3.5.1.3.  sort-by type is a list and sort-by node is an indirect descendent"
# alice, lin, bob, eric, joe
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><sort-by>stats/joined</sort-by></list-pagination></get></rpc>" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>alice</member-id>.*<member-id>lin</member-id>.*<member-id>bob</member-id>.*<member-id>eric</member-id>.*<member-id>joe</member-id>"

new "A.3.6.2.  where, match on descendent string containing a substring"
# bob, eric, alice, lin, joe
# Confusing: all match
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><where xmlns:ex=\"https://example.com/ns/example-social\">.[contains (es:email-address,'@example.com')]</where></list-pagination></get></rpc>" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>bob</member-id>.*<member-id>eric</member-id>.*<member-id>alice</member-id>.*<member-id>lin</member-id>.*<member-id>joe</member-id>"

new "A.3.6.3.  where, match on decendent timestamp starting with a substring"
# bob, eric, alice, joe,
# starts-with NYI, replaced with contains
# posts//post[starts-with(timestamp,'2020')]
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><where xmlns:ex=\"https://example.com/ns/example-social\">es:posts/es:post[contains(es:timestamp,'2020')]</where></list-pagination></get></rpc>" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>bob</member-id>.*<member-id>eric</member-id>.*<member-id>alice</member-id>.*<member-id>joe</member-id>"

new "A.3.9.1.  All six parameters at once"
# eric, bob
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><where xmlns:ex=\"https://example.com/ns/example-social\">//es:post[contains(es:timestamp,'2020')]</where><sort-by>member-id</sort-by><direction>backwards</direction><offset>2</offset><limit>2</limit></list-pagination></get></rpc>" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>eric</member-id>.*<member-id>bob</member-id>"

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

unset validatexml

rm -rf $dir

new "endtest"
endtest
