#!/usr/bin/env bash
# List pagination tests loosely based on draft-wwlh-netconf-list-pagination-00
# The example-social yang file is used
# Three tests to get state pagination data:
# 1. NETCONF get a specific list (alice->numbers)
# 2. NETCONF get two listsspecific list (alice+bob->numbers)
# 3. CLI get audit logs (only interactive)
# This tests contains a large state list: audit-logs from the example
# Only CLI is used
# Test also of list_pagination_partial_state extension

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fexample=$dir/example-social.yang
fstate=$dir/mystate.xml

# For 1M test,m use an external file since the generation takes considerable time
#fstate=~/tmp/mystate.xml

# Common example-module spec (fexample must be set)
. ./example_social.sh

# Validate internal state xml
: ${validatexml:=false}

# Number of audit-log entries 
: ${perfnr:=1000}

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
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
  <CLICON_CLI_OUTPUT_FORMAT>cli</CLICON_CLI_OUTPUT_FORMAT>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_VALIDATE_STATE_XML>$validatexml</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

# See draft-wwlh-netconf-list-pagination-00 A.2 (only stats and audit-log)
cat<<EOF > $fstate
<members xmlns="https://example.com/ns/example-social">
   <member>
      <member-id>alice</member-id>
      <stats>
          <numbers>3</numbers>
          <numbers>4</numbers>
          <numbers>5</numbers>
          <numbers>6</numbers>
          <numbers>7</numbers>
          <numbers>8</numbers>
      </stats>
   </member>
   <member>
      <member-id>bob</member-id>
      <stats>
          <numbers>13</numbers>
          <numbers>14</numbers>
          <numbers>15</numbers>
          <numbers>16</numbers>
          <numbers>17</numbers>
          <numbers>18</numbers>
      </stats>
   </member>
</members>
EOF

# Append generated state data to $fstate file
# Generation of random timestamps (not used)
# and succesive bob$i member-ids
new "generate state with $perfnr list entries"
echo "<audit-logs xmlns=\"https://example.com/ns/example-social\">" >> $fstate
for (( i=0; i<$perfnr; i++ )); do  
    echo "  <audit-log>" >> $fstate
    echo "    <timestamp>2021-09-05T018:48:11Z</timestamp>" >> $fstate
    echo "    <member-id>bob$i</member-id>" >> $fstate
    echo "    <source-ip>192.168.1.32</source-ip>" >> $fstate
    echo "    <request>POST</request>" >> $fstate
    echo "    <outcome>true</outcome>" >> $fstate
    echo "  </audit-log>" >> $fstate
done

echo -n "</audit-logs>" >> $fstate # No CR

# start backend with specific xpath
function testrun_start()
{
    xpath=$1

    new "test params: -f $cfg -s init -- -siS $fstate -x $xpath"
    if [ $BE -ne 0 ]; then
        new "kill old backend"
        sudo clixon_backend -zf $cfg
        if [ $? -ne 0 ]; then
            err
        fi
        sudo pkill -f clixon_backend # to be sure
        
        new "start backend -s init -f $cfg -- -siS $fstate -x $xpath"
        start_backend -s init -f $cfg -- -siS $fstate -x $xpath
    fi
    
    new "wait backend"
    wait_backend
}

function testrun_stop()
{
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
}

xpath0="/es:members/es:member[es:member-id='alice']/es:stats"
xpath="$xpath0/es:numbers"
testrun_start $xpath

new "NETCONF get leaf-list member/numbers 0-10 alice"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get content=\"nonconfig\"><filter type=\"xpath\" select=\"$xpath\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><offset>0</offset><limit>10</limit></list-pagination></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>alice</member-id><stats><numbers>3</numbers><numbers>4</numbers><numbers>5</numbers><numbers>6</numbers><numbers>7</numbers><numbers>8</numbers></stats></member></members></data></rpc-reply>"

# negative
new "NETCONF get container, expect fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get content=\"nonconfig\"><filter type=\"xpath\" select=\"$xpath0\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><offset>0</offset><limit>10</limit></list-pagination></get></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>list-pagination is enabled but target is not list or leaf-list</error-message></rpc-error></rpc-reply>"

xpath="/es:members/es:member[es:member-id='bob']/es:stats/es:numbers"
new "NETCONF get leaf-list member/numbers 0-10 bob"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get content=\"nonconfig\"><filter type=\"xpath\" select=\"$xpath\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><offset>0</offset><limit>10</limit></list-pagination></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>bob</member-id><stats><numbers>13</numbers><numbers>14</numbers><numbers>15</numbers><numbers>16</numbers><numbers>17</numbers><numbers>18</numbers></stats></member></members></data></rpc-reply>"

testrun_stop

#----------------------------
xpath="/es:members/es:member/es:stats/es:numbers"
testrun_start $xpath

new "NETCONF get leaf-list member/numbers all"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get content=\"nonconfig\"><filter type=\"xpath\" select=\"$xpath\" xmlns:es=\"https://example.com/ns/example-social\"/><list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><offset>0</offset><limit>10</limit></list-pagination></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><members xmlns=\"https://example.com/ns/example-social\"><member><member-id>alice</member-id><stats><numbers>3</numbers><numbers>4</numbers><numbers>5</numbers><numbers>6</numbers><numbers>7</numbers><numbers>8</numbers></stats></member><member><member-id>bob</member-id><stats><numbers>13</numbers><numbers>14</numbers><numbers>15</numbers><numbers>16</numbers></stats></member></members></data></rpc-reply>"

testrun_stop

#----------------------------

# Only if expect installed
if [ -n "$(type expect 2> /dev/null)" ]; then

    testrun_start "/es:audit-logs/es:audit-log"
    
    new "CLI scroll test using expect"
    xpath="/es:audit-logs/es:audit-log"
    sudo="sudo -g ${CLICON_GROUP}"		## cheat
    clixon_cli_="${clixon_cli##$sudo }"
#    echo "$sudo --preserve-env=clixon_cli expect ./test_pagination_expect.exp $cfg $xpath bob3 bob4"
    clixon_cli="$clixon_cli_" $sudo --preserve-env=clixon_cli expect ./test_pagination_expect.exp "$cfg" "$xpath" bob3 bob4
    if [ $? -ne 0 ]; then
        err1 "Failed: CLI show paginate state scroll using expect"
    fi

    testrun_stop

fi # expect

unset xpath0

rm -rf $dir

new "endtest"
endtest
