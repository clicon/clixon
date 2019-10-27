#!/usr/bin/env bash
# Tests for event streams using notifications
# Assumptions:
# 1. http server setup, such as nginx described in apps/restconf/README.md
#    especially SSE - ngchan setup
# 2. Example stream as Clixon example which needs registration, callback and
#    notification generating code every 5s
#
# Testing of streams is quite complicated.
# Here are some testing dimensions in restconf alone:
# - start/stop subscription
# - start-time/stop-time in subscription
# - stream retention time
# - native vs nchan implementation
# Focussing on 1-3
# 2a) start sub 8s - expect 2 notifications
# 2b) start sub 8s - stoptime after 5s - expect 1 notifications
# 2c) start sub 8s - replay from start -8s - expect 4 notifications
# 2d) start sub 8s - replay from start -8s to stop +4s - expect 3 notifications
# 2e) start sub 8s - replay from -90s w retention 60s - expect 10 notifications
# Note the sleeps are mainly for valgrind usage

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example
: ${clixon_util_stream:=clixon_util_stream}
NCWAIT=10 # Wait (netconf valgrind may need more time)

DATE=$(date +"%Y-%m-%d")

cfg=$dir/conf.xml
fyang=$dir/stream.yang
xml=$dir/xml.xml

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_STREAM_DISCOVERY_RFC5277>true</CLICON_STREAM_DISCOVERY_RFC5277>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_STREAM_PATH>streams</CLICON_STREAM_PATH>
  <CLICON_STREAM_URL>https://localhost</CLICON_STREAM_URL>
  <CLICON_STREAM_RETENTION>60</CLICON_STREAM_RETENTION>
</clixon-config>
EOF

# For nchan testing add this line to above config
#   <CLICON_STREAM_PUB>http://localhost/pub</CLICON_STREAM_PUB>

# RFC5277 NETCONF Event Notifications 
# using reportingEntity (rfc5277) not reporting-entity (rfc8040)
cat <<EOF > $fyang
     module example {
       namespace "urn:example:clixon";
       prefix ex;
       organization "Example, Inc.";
       contact "support at example.com";
       description "Example Notification Data Model Module.";
       revision "2016-07-07" {
         description "Initial version.";
         reference "example.com document 2-9976.";
       }
       notification event {
         description "Example notification event.";
         leaf event-class {
           type string;
           description "Event class identifier.";
         }
         container reportingEntity {
           description "Event specific information.";
           leaf card {
             type string;
             description "Line card identifier.";
           }
         }
         leaf severity {
           type string;
           description "Event severity description.";
         }
       }
       container state {
         config false;
         description "state data for the example application (must be here for example get operation)";
         leaf-list op {
            type string;
         }
       }
   }
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "waiting"
wait_backend

new "kill old restconf daemon"
sudo pkill -u $wwwuser clixon_restconf
      
new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_restconf

#
# 1. Netconf RFC5277 stream testing
new "1. Netconf RFC5277 stream testing"
# 1.1 Stream discovery
new "netconf event stream discovery RFC5277 Sec 3.2.5"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get><filter type="xpath" select="n:netconf/n:streams" xmlns:n="urn:ietf:params:xml:ns:netmod:notification"/></get></rpc>]]>]]>' '<rpc-reply><data><netconf xmlns="urn:ietf:params:xml:ns:netmod:notification"><streams><stream><name>EXAMPLE</name><description>Example event stream</description><replay-support>true</replay-support></stream></streams></netconf></data></rpc-reply>]]>]]>'

new "netconf event stream discovery RFC8040 Sec 6.2"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get><filter type="xpath" select="r:restconf-state/r:streams" xmlns:r="urn:ietf:params:xml:ns:yang:ietf-restconf-monitoring"/></get></rpc>]]>]]>' '<rpc-reply><data><restconf-state xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf-monitoring"><streams><stream><name>EXAMPLE</name><description>Example event stream</description><replay-support>true</replay-support><access><encoding>xml</encoding><location>https://localhost/streams/EXAMPLE</location></access></stream></streams></restconf-state></data></rpc-reply>]]>]]>'

#
# 1.2 Netconf stream subscription
new "netconf EXAMPLE subscription"
expectwait "$clixon_netconf -qf $cfg" '<rpc><create-subscription xmlns="urn:ietf:params:xml:ns:netmod:notification"><stream>EXAMPLE</stream></create-subscription></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' $NCWAIT

new "netconf subscription with empty startTime"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><create-subscription xmlns="urn:ietf:params:xml:ns:netmod:notification"><stream>EXAMPLE</stream><startTime/></create-subscription></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>startTime</bad-element></error-info><error-severity>error</error-severity><error-message>regexp match fail:'

new "netconf EXAMPLE subscription with simple filter"
expectwait "$clixon_netconf -qf $cfg" '<rpc><create-subscription xmlns="urn:ietf:params:xml:ns:netmod:notification"><stream>EXAMPLE</stream><filter type="xpath" select="event"/></create-subscription></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' $NCWAIT

new "netconf EXAMPLE subscription with filter classifier"
expectwait "$clixon_netconf -qf $cfg" "<rpc><create-subscription xmlns=\"urn:ietf:params:xml:ns:netmod:notification\"><stream>EXAMPLE</stream><filter type=\"xpath\" select=\"event[event-class='fault']\"/></create-subscription></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' $NCWAIT

new "netconf NONEXIST subscription"
expectwait "$clixon_netconf -qf $cfg" '<rpc><create-subscription xmlns="urn:ietf:params:xml:ns:netmod:notification"><stream>NONEXIST</stream></create-subscription></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>No such stream</error-message></rpc-error></rpc-reply>]]>]]>$' $NCWAIT

new "netconf EXAMPLE subscription with wrong date"
expectwait "$clixon_netconf -qf $cfg" '<rpc><create-subscription xmlns="urn:ietf:params:xml:ns:netmod:notification"><stream>EXAMPLE</stream><startTime>kallekaka</startTime></create-subscription></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>startTime</bad-element></error-info><error-severity>error</error-severity><error-message>regexp match fail:' 0

#new "netconf EXAMPLE subscription with replay"
#NOW=$(date +"%Y-%m-%dT%H:%M:%S")
#sleep 10
#expectwait "$clixon_netconf -qf $cfg" "<rpc><create-subscription xmlns=\"urn:ietf:params:xml:ns:netmod:notification\"><stream>EXAMPLE</stream><startTime>$NOW</startTime></create-subscription></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' 10
sleep 1

#
# 2. Restconf RFC8040 stream testing
new "2. Restconf RFC8040 stream testing"
# 2.1 Stream discovery
new "restconf event stream discovery RFC8040 Sec 6.2"
expectfn "curl -s -X GET http://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/streams" 0 '{"ietf-restconf-monitoring:streams":{"stream":\[{"name":"EXAMPLE","description":"Example event stream","replay-support":true,"access":\[{"encoding":"xml","location":"https://localhost/streams/EXAMPLE"}\]}\]}'

sleep 1
new "restconf subscribe RFC8040 Sec 6.3, get location"
expectfn "curl -s -X GET http://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/streams/stream=EXAMPLE/access=xml/location" 0 '{"ietf-restconf-monitoring:location":"https://localhost/streams/EXAMPLE"}'

sleep 1
# Restconf stream subscription RFC8040 Sec 6.3
# Start Subscription w error
new "restconf monitor event nonexist stream"
expectwait 'curl -s -X GET -H "Accept: text/event-stream" -H "Cache-Control: no-cache" -H "Connection: keep-alive" http://localhost/streams/NOTEXIST' 0 '<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-type>application</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>No such stream</error-message></error></errors>' 2

# 2a) start subscription 8s - expect 1-2 notifications
new "2a) start subscriptions 8s - expect 1-2 notifications"
ret=$($clixon_util_stream -u http://localhost/streams/EXAMPLE -t 8)
expect="data: <notification xmlns=\"urn:ietf:params:xml:ns:netconf:notification:1.0\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"

match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi
nr=$(echo "$ret" | grep -c "data:")
if [ $nr -lt 1 -o $nr -gt 2 ]; then
    err 2 "$nr"
fi

sleep 1

# 2b) start subscription 8s - stoptime after 5s - expect 1-2 notifications
new "2b) start subscriptions 8s - stoptime after 5s - expect 1-2 notifications"
ret=$($clixon_util_stream -u http://localhost/streams/EXAMPLE -t 8 -e +10)
expect="data: <notification xmlns=\"urn:ietf:params:xml:ns:netconf:notification:1.0\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"
match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi
nr=$(echo "$ret" | grep -c "data:")
if [ $nr -lt 1 -o $nr -gt 2 ]; then
    err 1 "$nr"
fi

sleep 1

# 2c
new "2c) start sub 8s - replay from start -8s - expect 3-4 notifications"
ret=$($clixon_util_stream -u http://localhost/streams/EXAMPLE -t 10 -s -8)
expect="data: <notification xmlns=\"urn:ietf:params:xml:ns:netconf:notification:1.0\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"
match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi
nr=$(echo "$ret" | grep -c "data:")
#if [ $nr -lt 3 -o $nr -gt 4 ]; then
if [ $nr -lt 3 ]; then
    err 4 "$nr"
fi
sleep 1

# 2d) start sub 8s - replay from start -8s to stop +4s - expect 3 notifications
new "2d) start sub 8s - replay from start -8s to stop +4s - expect 3 notifications"
ret=$($clixon_util_stream -u http://localhost/streams/EXAMPLE -t 10 -s -30 -e +4)
expect="data: <notification xmlns=\"urn:ietf:params:xml:ns:netconf:notification:1.0\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"
match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi
nr=$(echo "$ret" | grep -c "data:")
#if [ $nr -lt 4 -o $nr -gt 10 ]; then
if [ $nr -lt 4 ]; then
    err 6 "$nr"
fi

sleep 1

# 2e) start sub 8s - replay from -90s w retention 60s - expect 10 notifications
new "2e) start sub 8s - replay from -90s w retention 60s - expect 10 notifications"
ret=$($clixon_util_stream -u http://localhost/streams/EXAMPLE -t 10 -s -90 -e +0)
expect="data: <notification xmlns=\"urn:ietf:params:xml:ns:netconf:notification:1.0\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"
match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi
nr=$(echo "$ret" | grep -c "data:")

if [ $nr -lt 9 -o $nr -gt 14 ]; then
    err 10 "$nr"
fi

sleep 1

# Try parallell
# start background job
curl -s -X GET  -H "Accept: text/event-stream" -H "Cache-Control: no-cache" -H "Connection: keep-alive" "http://localhost/streams/EXAMPLE" > /dev/null &
PID=$!

new "Start subscriptions in parallell"
ret=$($clixon_util_stream -u http://localhost/streams/EXAMPLE -t 8)
expect="data: <notification xmlns=\"urn:ietf:params:xml:ns:netconf:notification:1.0\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"

match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi
nr=$(echo "$ret" | grep -c "data:")
if [ $nr -lt 1 -o $nr -gt 2 ]; then
    err 2 "$nr"
fi

kill $PID

#--------------------------------------------------------------------
# NCHAN Need manual testing
echo "Nchan streams requires manual testing"
echo "Add <CLICON_STREAM_PUB>http://localhost/pub</CLICON_STREAM_PUB> to config"
echo "Eg: curl -H \"Accept: text/event-stream\" -s -X GET http://localhost/sub/EXAMPLE"

#-----------------
sleep 5
new "Kill restconf daemon"
stop_restconf 

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
