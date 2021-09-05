#!/usr/bin/env bash
# List pagination tests loosely based on draft-wwlh-netconf-list-pagination-00
# The example-social yang file is used
# This tests contains a large state list: audit-logs from the example
# Only CLI is used

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

echo "...skipped: Must run interactvely"
if [ "$s" = $0 ]; then exit 0; else return 0; fi

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
  <CLICON_XMLDB_FORMAT>json</CLICON_XMLDB_FORMAT>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_VALIDATE_STATE_XML>$validatexml</CLICON_VALIDATE_STATE_XML>
</clixon-config>
EOF

# See draft-wwlh-netconf-list-pagination-00 A.2 (only stats and audit-log)
# XXX members not currently used, only audit-logs as generated below
cat<<EOF > $fstate
EOF

# Append generated state data to $fstate file
# Generation of random timestamps (not used)
# and succesive bob$i member-ids
new "generate state with $perfnr list entries"
echo "<audit-logs xmlns=\"http://example.com/ns/example-social\">" >> $fstate
for (( i=0; i<$perfnr; i++ )); do  
    echo "  <audit-log>" >> $fstate
    echo "    <timestamp>2021-09-05T018:48:11Z</timestamp>" >> $fstate
    echo "    <member-id>bob$i</member-id>" >> $fstate
    echo "    <source-ip>192.168.1.32</source-ip>" >> $fstate
    echo "    <request>POST</request>" >> $fstate
    echo "  </audit-log>" >> $fstate
done
echo -n "</audit-logs>" >> $fstate # No CR

new "test params: -f $cfg -s init -- -siS $fstate"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure

    new "start backend -s init -f $cfg -- -siS $fstate"
    start_backend -s init -f $cfg -- -siS $fstate
fi

new "wait backend"
wait_backend

# XXX How to run without using a terminal?
new "cli show"
echo "$clixon_cli -1 -f $cfg -l o show pagination xpath /es:audit-logs/es:audit-log cli"
$clixon_cli -1 -f $cfg -l o show pagination xpath /es:audit-logs/es:audit-log cli

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
