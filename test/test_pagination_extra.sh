#!/usr/bin/env bash
# List pagination tests according to draft-ietf-netconf-list-pagination-15
# direction, sort-by, where and combinations in Appendix A.3.4, A.3.5, A.3.6 and A.3.9
# Only NETCONF, see RESTCONF variants in test_pagination_draft.sh

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
  <CLICON_FEATURE>ietf-list-pagination:sort-by</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-list-pagination:direction</CLICON_FEATURE>
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

# See draft-ietf-netconf-list-pagination-15 A.2 (except stats and audit-log)
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

# See draft-ietf-netconf-list-pagination-15 A.2 (only stats and audit-log)
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

new "netconf yang-library: ietf-list-pagination module, RFC 8525"
rpc=$(chunked_framing "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"l:yang-library/l:module-set[l:name='top']/l:module[l:name='ietf-list-pagination']\" xmlns:l=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\"/></get></rpc>")
ret=$($clixon_netconf -qf $cfg<<EOF
$DEFAULTHELLO$rpc
EOF
   )

new "Check: sort-by, where and offset all announced as enabled features"
expect1="<module><name>ietf-list-pagination</name><revision>"
expect2="</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-list-pagination</namespace><feature>direction</feature><feature>offset</feature><feature>sort-by</feature><feature>where</feature></module>"
match=`echo "$ret" | grep --null -Go "$expect1"`
if [ -z "$match" ]; then
      err "$expect1" "$ret"
fi
match=`echo "$ret" | grep --null -Go "$expect2"`
if [ -z "$match" ]; then
      err "$expect2" "$ret"
fi



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

# where tests: where is parsed and evaluated separately per entry (draft-15 Sec 3.1.1)
# Prefixes are declared on the where element (-nc Sec 4.1.7), unprefixed names have the
# namespace of the target node (RFC 7950 6.4.1)
GETMEMBERS="<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\">"
MEMBERSREPLY="<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\">"
WHEREERR="<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>"

new "A.3.6.1.  where, match of leaf-list's values"
# NOTE: the draft's where "uint8-numbers[. > 7]" evaluates to false with a leaf-list
# entry as context node, ". > 7" is used instead
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/es:members/es:member[es:member-id='alice']/es:favorites/es:uint8-numbers\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><where>. &gt; 7</where></list-pagination></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>alice</member-id><favorites><uint8-numbers>17</uint8-numbers><uint8-numbers>13</uint8-numbers><uint8-numbers>11</uint8-numbers></favorites></member></members></data></rpc-reply>"

new "A.3.6.2.  where, match on descendant string containing a substring"
# alice, bob, eric, joe, lin (member is ordered-by system: canonicalized by key.
# DEVIATION: the draft's own dataset order is bob, eric, alice, lin, joe
# All match since lin is lin@example.com in this data set
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$GETMEMBERS<where>.[contains(email-address,'@example.com')]</where></list-pagination></get></rpc>" "${MEMBERSREPLY}<member><member-id>alice</member-id>.*<member-id>bob</member-id>.*<member-id>eric</member-id>.*<member-id>joe</member-id>.*<member-id>lin</member-id>"

new "A.3.6.2.  where, prefixed, prefix declared on where element"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$GETMEMBERS<where xmlns:es=\"https://example.com/ns/example-social\">.[contains(es:email-address,'@example.com')]</where></list-pagination></get></rpc>" "${MEMBERSREPLY}<member><member-id>alice</member-id>.*<member-id>bob</member-id>.*<member-id>eric</member-id>.*<member-id>joe</member-id>.*<member-id>lin</member-id>"

new "A.3.6.3.  where, match on descendant timestamp starting with a substring"
# alice, bob, eric, joe (member is ordered-by system: canonicalized by key), not lin (no posts)
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$GETMEMBERS<where>posts/post[starts-with(timestamp,'2020')]</where></list-pagination></get></rpc>" "${MEMBERSREPLY}<member><member-id>alice</member-id>.*<member-id>bob</member-id>.*<member-id>eric</member-id>.*<member-id>joe</member-id>" "" --not-- "<member-id>lin</member-id>"

new "where, undefined prefix -> invalid-value"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$GETMEMBERS<where>.[contains(ex:email-address,'x')]</where></list-pagination></get></rpc>" "${WHEREERR}Undefined prefix"

new "where, invalid XPath -> invalid-value"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$GETMEMBERS<where>.[contains(</where></list-pagination></get></rpc>" "${WHEREERR}Invalid XPath"

new "where, attempt to break out of predicate -> invalid-value"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$GETMEMBERS<where xmlns:es=\"https://example.com/ns/example-social\">true()] | /es:members/es:member[false()</where></list-pagination></get></rpc>" "${WHEREERR}Invalid XPath"

new "A.3.9.1.  All six parameters at once"
# eric, bob
# NOTE: the draft's where "stats/joined[starts-with(timestamp,'2020')]" is invalid (joined
# is a leaf), "starts-with(stats/joined,'2020')" is used instead. sublist-limit is NYI
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "$GETMEMBERS<where>starts-with(stats/joined,'2020')</where><sort-by>member-id</sort-by><direction>backwards</direction><offset>2</offset><limit>2</limit></list-pagination></get></rpc>" "${MEMBERSREPLY}<member lpg:remaining=\"1\" xmlns:lpg=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination\"><member-id>eric</member-id>.*<member-id>bob</member-id>"

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
