#!/usr/bin/env bash
# Tests for event streams using notifications
# See RFC5277 NETCONF Event Notifications
#     RFC8040 Sec 6.2
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

# Dont run this test with valgrind
if [ $valgrindtest -ne 0 ]; then
    echo "...skipped "
    rm -rf $dir
    return 0 # skip
fi

: ${SLEEP2:=1}
SLEEP5=.5
APPNAME=example

: ${TIMEOUT:=10}
: ${PERIOD:=2}
: ${clixon_util_stream:=clixon_util_stream}

# Lower and upper bound on number of intervals
LBOUND=$((${TIMEOUT}/${PERIOD} - 1))
UBOUND=$((${TIMEOUT}/${PERIOD} + 1))

# Ensure UTC
DATE=$(date -u +"%Y-%m-%d")

cfg=$dir/conf.xml
cfd=$dir/conf.d
if [ ! -d $cfd ]; then
    mkdir $cfd
fi
fyang=$dir/stream.yang
xml=$dir/xml.xml

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)
if [ $? -ne 0 ]; then
    err1 "Error when generating certs"
fi

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_CONFIGDIR>$cfd</CLICON_CONFIGDIR>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_STREAM_DISCOVERY_RFC5277>true</CLICON_STREAM_DISCOVERY_RFC5277>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_STREAM_PATH>streams</CLICON_STREAM_PATH>
  <CLICON_STREAM_RETENTION>60</CLICON_STREAM_RETENTION>
</clixon-config>
EOF

cat <<EOF > $cfd/restconf.xml
<clixon-config xmlns="http://clicon.org/config">
  $RESTCONFIG
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

# Run stream test
# Args:
# 1: extra curlopt
# 2: pretty (ie multi-line)
function runtest()
{
    extra=$1
    pretty=$2

    if $pretty; then
        expect=$(cat <<EOF
data: <notification xmlns="${NOTIFICATION_NS}">
data:   <eventTime>2025-09-04T09:50:08.986985Z</eventTime>
data:   <event xmlns="urn:example:clixon">
data:      <event-class>fault</event-class>
data:      <reportingEntity>
data:         <card>Ethernet0</card>
data:      </reportingEntity>
data:      <severity>major</severity>
data:   </event>
data: </notification>
EOF
)
    else
        expect="data: <notification xmlns=\"${NOTIFICATION_NS}\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"
    fi

    new "2a) start $extra timeout:${TIMEOUT}s - expect ${LBOUND}-${UBOUND} notifications"
    ret=$(curl $CURLOPTS $extra -X GET -H "Accept: text/event-stream" -H "Cache-Control: no-cache" -H "Connection: keep-alive" $RCPROTO://localhost/streams/EXAMPLE)
    match=$(echo "$ret" | grep -Eo "$expect")
#    echo "ret:$ret"
    if [ -z "$match" ]; then
        err "$expect" "$ret"
    fi

    nr=$(echo "$ret" | grep -c "<notification xmlns=\"${NOTIFICATION_NS}\">")
    if [ $nr -lt ${LBOUND} -o $nr -gt ${UBOUND} ]; then
        err "[${LBOUND},$[UBOUND]]" "$nr"
    fi

    LB=$((5/${PERIOD} - 1))
    UB=$((5/${PERIOD} + 1))

    # date differs between -d and -v for declaring a later date
    if [ $(date -u -v+5S +'%Y-%m-%dT%H:%M:%SZ' 2> /dev/null) ]; then
        time1=$(date -u -v+5S +'%Y-%m-%dT%H:%M:%SZ')
    else
        time1=$(date -u -d"5 second now" +'%Y-%m-%dT%H:%M:%SZ')
    fi

    new "2b) start $extra timeout:${TIMEOUT} stop after 5s - expect ${LB}-${UB} notifications"
    ret=$(curl $CURLOPTS $extra -X GET -H "Accept: text/event-stream" -H "Cache-Control: no-cache" -H "Connection: keep-alive" $RCPROTO://localhost/streams/EXAMPLE?stop-time=${time1})
    match=$(echo "$ret" | grep -Eo "$expect")
    if [ -z "$match" ]; then
        err "$expect" "$ret"
    fi

    nr=$(echo "$ret" | grep -c "<notification xmlns=\"${NOTIFICATION_NS}\">")
    if [ $nr -lt ${LB} -o $nr -gt ${UB} ]; then
        err "[${LB},$[UB]]" "$nr"
    fi

    if false; then # Does not work yet
        if [ $(date -u -v+5S +'%Y-%m-%dT%H:%M:%SZ' 2> /dev/null) ]; then
            time1=$(date -u -v+5S +'%Y-%m-%dT%H:%M:%SZ')
        else
            time1=$(date -u -d"5 second now" +'%Y-%m-%dT%H:%M:%SZ')
        fi
        LB=$(((5+${TIMEOUT})/${PERIOD} - 1))
        UB=$(((5+${TIMEOUT})/${PERIOD} + 1))
        new "2c) start sub 8s - replay from start -8s - expect 3-4 notifications"
        echo "curl $CURLOPTS $extra -X GET -H \"Accept: text/event-stream\" -H \"Cache-Control: no-cache\" -H \"Connection: keep-alive\" $RCPROTO://localhost/streams/EXAMPLE?start-time=${time1}"
        ret=$(curl $CURLOPTS $extra -X GET -H "Accept: text/event-stream" -H "Cache-Control: no-cache" -H "Connection: keep-alive" $RCPROTO://localhost/streams/EXAMPLE?start-time=${time1})
    fi

    unset LB
    unset UB
    unset time1
}

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend # to be sure
fi
if [ $BE -ne 0 ]; then
    new "start backend -s init -f $cfg -- -n ${PERIOD}"
    # create example notification stream with periodic timeout ${PERIOD} seconds
    start_backend -s init -f $cfg -- -n ${PERIOD}
fi

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    sleep 1
    new "start restconf daemon -f $cfg -t ${TIMEOUT}"
    start_restconf -f $cfg -t ${TIMEOUT}
fi

new "wait restconf 1"
wait_restconf

if [ "${WITH_RESTCONF}" = "fcgi" ]; then
    location="https://localhost/streams/EXAMPLE"
else
    location="$RCPROTO://localhost/streams/EXAMPLE"
fi

new "netconf event stream discovery RFC8040 Sec 6.2"
expecteof_netconf "$clixon_netconf -D $DBG -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"r:restconf-state/r:streams\" xmlns:r=\"urn:ietf:params:xml:ns:yang:ietf-restconf-monitoring\"/></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><restconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-restconf-monitoring\"><streams><stream><name>EXAMPLE</name><description>Example event stream</description><replay-support>true</replay-support><access><encoding>xml</encoding><location>${location}</location></access></stream></streams></restconf-state></data></rpc-reply>"

# 1.2 Netconf stream subscription

# 2. Restconf RFC8040 stream testing
new "2. Restconf RFC8040 stream testing"
# 2.1 Stream discovery
new "restconf event stream discovery RFC8040 Sec 6.2"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/streams)" 0 "HTTP/$HVER 200" "{\"ietf-restconf-monitoring:streams\":{\"stream\":\[{\"name\":\"EXAMPLE\",\"description\":\"Example event stream\",\"replay-support\":true,\"access\":\[{\"encoding\":\"xml\",\"location\":\"${location}\"}\]}\]}"

new "restconf subscribe RFC8040 Sec 6.3, get location"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/streams/stream=EXAMPLE/access=xml/location)" 0 "HTTP/$HVER 200" "{\"ietf-restconf-monitoring:location\":\"${location}\"}"

# Restconf stream subscription RFC8040 Sec 6.3
# Start Subscription w error
new "Try nonexist stream"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: text/event-stream" -H "Cache-Control: no-cache" -H "Connection: keep-alive" $RCPROTO://localhost/streams/NOTEXIST)" 0 "HTTP/$HVER 400" "<errors xmlns=\"urn:ietf:params:xml:ns:yang:ietf-restconf\"><error><error-type>application</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>No such stream</error-message></error></errors>"

if ${HAVE_HTTP1}; then
    new "HTTP-1.1 streams"
    runtest --http1.1 false
fi
if [ "${WITH_RESTCONF}" = "fcgi" ]; then
    new "Fcgi streams"
    runtest "" false
fi
if [ "${WITH_RESTCONF}" = "native" ]; then
    if ${HAVE_LIBNGHTTP2}; then
        new "HTTP-2 streams"
        runtest --http2 false
    fi
fi

if false; then # NYI

# 2c
new "2c) start sub 8s - replay from start -8s - expect 3-4 notifications"
ret=$($clixon_util_stream -u $RCPROTO://localhost/streams/EXAMPLE -t 10 -s -8)
expect="data: <notification xmlns=\"${NOTIFICATION_NS}\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"
match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

nr=$(echo "$ret" | grep -c "<notification xmlns=\"${NOTIFICATION_NS}\">")

#if [ $nr -lt 3 -o $nr -gt 4 ]; then
if [ $nr -lt 3 ]; then
    err 4 "$nr"
fi

test-pause

# 2d) start sub 8s - replay from start -8s to stop +4s - expect 3 notifications
new "2d) start sub 8s - replay from start -8s to stop +4s - expect 3 notifications"
ret=$($clixon_util_stream -u $RCPROTO://localhost/streams/EXAMPLE -t 10 -s -30 -e +4)
expect="data: <notification xmlns=\"${NOTIFICATION_NS}\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"
match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

nr=$(echo "$ret" | grep -c "<notification xmlns=\"${NOTIFICATION_NS}\">")

#if [ $nr -lt 4 -o $nr -gt 10 ]; then
if [ $nr -lt 4 ]; then
    err 6 "$nr"
fi

test-pause

if false; then # XXX Should work but function detoriated
# 2e) start sub 8s - replay from -90s w retention 60s - expect 9-14 notifications
new "2e) start sub 8s - replay from -90s w retention 60s - expect 10 notifications"
ret=$($clixon_util_stream -u $RCPROTO://localhost/streams/EXAMPLE -t 10 -s -90 -e +0)
expect="data: <notification xmlns=\"${NOTIFICATION_NS}\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"

match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi
nr=$(echo "$ret" | grep -c "<notification xmlns=\"${NOTIFICATION_NS}\">")

if [ $nr -lt 8 -o $nr -gt 14 ]; then
    err "8-14" "$nr"
fi

test-pause
sleep 5

# Start curl in background and save PID
curl $CURLOPTS -X GET  -H "Accept: text/event-stream" -H "Cache-Control: no-cache" -H "Connection: keep-alive" "$RCPROTO://localhost/streams/EXAMPLE" & # > /dev/null &
PID=$!

new "Start subscription"
ret=$($clixon_util_stream -u $RCPROTO://localhost/streams/EXAMPLE -t 8)
expect="data: <notification xmlns=\"${NOTIFICATION_NS}\"><eventTime>${DATE}T[0-9:.]*Z</eventTime><event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>"

match=$(echo "$ret" | grep -Eo "$expect")
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi
nr=$(echo "$ret" | grep -c "<notification xmlns=\"${NOTIFICATION_NS}\">")
if [ $nr -lt 1 -o $nr -gt 2 ]; then
    err 2 "$nr"
fi

fi # XXX

kill $PID

#-----------------
sleep $SLEEP5

fi # XXX

# Multi-line notification
if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

# Set pretty-print
RESTCONFIG=$(restconf_config none true)

cat <<EOF > $cfd/restconf.xml
<clixon-config xmlns="http://clicon.org/config">
  $RESTCONFIG
</clixon-config>
EOF

if [ $RC -ne 0 ]; then
    sleep 1
    new "start restconf daemon -f $cfg -t ${TIMEOUT}"
    start_restconf -f $cfg -t ${TIMEOUT}
fi

new "wait restconf 2"
wait_restconf

#if ${HAVE_HTTP1}; then
#    new "HTTP-1.1 streams pretty-print"
#    runtest --http1.1 true
#fi
if [ "${WITH_RESTCONF}" = "fcgi" ]; then
    new "Fcgi streams pretty-print"
    runtest "" true
fi
if [ "${WITH_RESTCONF}" = "native" ]; then
    if ${HAVE_LIBNGHTTP2}; then
        new "HTTP-2 streams pretty-print"
        runtest --http2 true
    fi
fi

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

new "Endtest"
endtest

rm -rf $dir
