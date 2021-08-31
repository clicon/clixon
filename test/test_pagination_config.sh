#!/usr/bin/env bash
# List pagination tests loosely based on draft-wwlh-netconf-list-pagination-00
# The example-social yang file is used
# This tests contains a large config list: members/member/favorites/uint8-numbers

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

echo "...skipped: Must run interactvely"
if [ "$s" = $0 ]; then exit 0; else return 0; fi
    
APPNAME=example

cfg=$dir/conf.xml
fexample=$dir/example-social.yang

# Common example-module spec (fexample must be set)
. ./example_social.sh

# Validate internal state xml
: ${validatexml:=false}

# Number of audit-log entries 
#: ${perfnr:=20000}
: ${perfnr:=200}

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_FORMAT>xml</CLICON_XMLDB_FORMAT>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_VALIDATE_STATE_XML>$validatexml</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

# Based on draft-wwlh-netconf-list-pagination-00 A.2 but bob has a generated uint8-numbers list
# start file
cat <<'EOF' > $dir/startup_db
<config>
  <members xmlns="http://example.com/ns/example-social">
    <member>
      <member-id>alice</member-id>
      <email-address>alice@example.com</email-address>
      <password>$0$1543</password>
      <avatar>BASE64VALUE=</avatar>
      <tagline>Every day is a new day</tagline>
      <privacy-settings>
         <hide-network>false</hide-network>
         <post-visibility>public</post-visibility>
      </privacy-settings>
      <following>bob</following>
      <following>eric</following>
      <following>lin</following>
      <posts>
         <post>
            <timestamp>2020-07-08T13:12:45Z</timestamp>
            <title>My first post</title>
            <body>Hiya all!</body>
         </post>
         <post>
            <timestamp>2020-07-09T01:32:23Z</timestamp>
            <title>Sleepy...</title>
            <body>Catch y'all tomorrow.</body>
         </post>
      </posts>
      <favorites>
         <uint64-numbers>17</uint64-numbers>
         <uint64-numbers>13</uint64-numbers>
         <uint64-numbers>11</uint64-numbers>
         <uint64-numbers>7</uint64-numbers>
         <uint64-numbers>5</uint64-numbers>
         <uint64-numbers>3</uint64-numbers>
         <int8-numbers>-5</int8-numbers>
         <int8-numbers>-3</int8-numbers>
         <int8-numbers>-1</int8-numbers>
         <int8-numbers>1</int8-numbers>
         <int8-numbers>3</int8-numbers>
         <int8-numbers>5</int8-numbers>
      </favorites>
   </member>
   <member>
      <member-id>bob</member-id>
      <email-address>bob@example.com</email-address>
      <password>$0$1543</password>
      <avatar>BASE64VALUE=</avatar>
      <tagline>Here and now, like never before.</tagline>
      <privacy-settings>
         <post-visibility>public</post-visibility>
      </privacy-settings>
      <posts>
         <post>
            <timestamp>2020-08-14T03:32:25Z</timestamp>
            <body>Just got in.</body>
         </post>
         <post>
            <timestamp>2020-08-14T03:33:55Z</timestamp>
            <body>What's new?</body>
         </post>
         <post>
            <timestamp>2020-08-14T03:34:30Z</timestamp>
            <body>I'm bored...</body>
         </post>
      </posts>
      <favorites>
EOF

new "generate config with $perfnr leaf-list entries"
for (( i=0; i<$perfnr; i++ )); do  
    echo "          <uint64-numbers>$i</uint64-numbers>" >> $dir/startup_db
done

# end file
cat <<'EOF' >> $dir/startup_db
         <int8-numbers>-9</int8-numbers>
         <int8-numbers>2</int8-numbers>
      </favorites>
    </member>
  </members>
</config>
EOF

new "test params: -f $cfg -s startup"

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

# XXX How to run without using a terminal?
new "cli show"
$clixon_cli -f $cfg -l o -1 show pagination xpath /es:members/es:member[es:member-id=\'bob\']/es:favorites/es:uint64-numbers cli
#expectpart "$(echo "show pagination xpath /es:members/es:member[es:member-id=\'bob\']/es:favorites/es:uint64-numbers cli" | $clixon_cli -f $cfg -l o)" 0 foo
#expectpart "$($clixon_cli -1 -f $cfg -l o show pagination xpath /es:members/es:member[es:member-id=\'bob\']/es:favorites/es:uint64-numbers cli)" 0 foo

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
unset perfnr

rm -rf $dir

new "endtest"
endtest
