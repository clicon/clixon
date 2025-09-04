#!/usr/bin/env bash
# Tests for Netconf event streams using notifications
# See RFC5277 NETCONF Event Notifications
#
# Testing of streams is quite complicated.
# Here are some testing dimensions in restconf alone:
# - start/stop subscription
# - start-time/stop-time in subscription
# - stream retention time
# - native vs nchan implementation
# Focussing on 1-3
# @see test_restconf_notifications.sh

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

NCWAIT=10 # Wait (netconf valgrind may need more time)

# Ensure UTC
DATE=$(date -u +"%Y-%m-%d")

cfg=$dir/conf.xml
fyang=$dir/example.yang
xml=$dir/xml.xml

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
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
  <CLICON_STREAM_PATH>streams</CLICON_STREAM_PATH>
  <CLICON_STREAM_RETENTION>60</CLICON_STREAM_RETENTION>
  <CLICON_NETCONF_MONITORING>true</CLICON_NETCONF_MONITORING>
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
    new "start backend -s init -f $cfg -- -n 5"
    start_backend -s init -f $cfg -- -n 5 # create example notification stream
fi

new "wait backend"
wait_backend

#
# 1. Netconf RFC5277 stream testing
new "1. Netconf RFC5277 stream testing"
# 1.1 Stream discovery
new "netconf event stream discovery RFC5277 Sec 3.2.5"
expecteof_netconf "$clixon_netconf -D $DBG -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"n:netconf/n:streams\" xmlns:n=\"urn:ietf:params:xml:ns:netmod:notification\"/></get></rpc>" "" "<rpc-reply $DEFAULTNS><data><netconf xmlns=\"urn:ietf:params:xml:ns:netmod:notification\"><streams><stream><name>EXAMPLE</name><description>Example event stream</description><replay-support>true</replay-support></stream></streams></netconf></data></rpc-reply>"

new "netconf EXAMPLE subscription"
expectwait "$clixon_netconf -D $DBG -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><create-subscription xmlns=\"urn:ietf:params:xml:ns:netmod:notification\"><stream>EXAMPLE</stream></create-subscription></rpc>" $NCWAIT "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" "<notification xmlns=\"${NOTIFICATION_NS}\"><eventTime>20"

new "netconf subscription with empty startTime"
expecteof_netconf "$clixon_netconf -D $DBG -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><create-subscription xmlns=\"urn:ietf:params:xml:ns:netmod:notification\"><stream>EXAMPLE</stream><startTime/></create-subscription></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>startTime</bad-element></error-info><error-severity>error</error-severity><error-message>regexp match fail:" ""

new "out-notification statistics expect 1-3"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><statistics><out-notifications/></statistics></netconf-state></filter></get></rpc>" "<rpc-reply $DEFAULTNS><data><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><statistics><out-notifications>[1-3]</out-notifications></statistics></netconf-state></data></rpc-reply>"

new "netconf EXAMPLE subscription with simple filter"
expectwait "$clixon_netconf -D $DBG -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><create-subscription xmlns=\"urn:ietf:params:xml:ns:netmod:notification\"><stream>EXAMPLE</stream><filter type=\"xpath\" select=\"event\"/></create-subscription></rpc>" $NCWAIT "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" "<notification xmlns=\"${NOTIFICATION_NS}\"><eventTime>20"

new "netconf EXAMPLE subscription with filter classifier"
expectwait "$clixon_netconf -D $DBG -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><create-subscription xmlns=\"urn:ietf:params:xml:ns:netmod:notification\"><stream>EXAMPLE</stream><filter type=\"xpath\" select=\"event[event-class='fault']\"/></create-subscription></rpc>" $NCWAIT "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" "<notification xmlns=\"${NOTIFICATION_NS}\"><eventTime>20"

new "netconf NONEXIST subscription"
expectwait "$clixon_netconf -D $DBG -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><create-subscription xmlns=\"urn:ietf:params:xml:ns:netmod:notification\"><stream>NONEXIST</stream></create-subscription></rpc>" $NCWAIT "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>No such stream</error-message></rpc-error></rpc-reply>"

new "netconf EXAMPLE subscription with wrong date"
expectwait "$clixon_netconf -D $DBG -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><create-subscription xmlns=\"urn:ietf:params:xml:ns:netmod:notification\"><stream>EXAMPLE</stream><startTime>kallekaka</startTime></create-subscription></rpc>" 0 "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>startTime</bad-element></error-info><error-severity>error</error-severity><error-message>regexp match fail:"

#new "netconf EXAMPLE subscription with replay"
#NOW=$(date +"%Y-%m-%dT%H:%M:%S")
#sleep 10
#expectwait "$clixon_netconf -D $DBG -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><create-subscription xmlns=\"urn:ietf:params:xml:ns:netmod:notification\"><stream>EXAMPLE</stream><startTime>$NOW</startTime></create-subscription></rpc>" 10 "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]><notification xmlns=\"${NOTIFICATION_NS}\"><eventTime>20"

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

rm -rf $dir

new "endtest"
endtest
