#!/bin/bash
# Tests for event streams using notifications
# Assumptions:
# 1. http server setup, such as nginx described in apps/restconf/README.md
#    especially SSE - ngchan setup
# 2. Example stream as Clixon example which needs registration, callback and
#    notification generating code

APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh
cfg=$dir/conf.xml
fyang=$dir/restconf.yang
xml=$dir/xml.xml


#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_STREAM_DISCOVERY_RFC5277>true</CLICON_STREAM_DISCOVERY_RFC5277>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_STREAM_PATH>streams</CLICON_STREAM_PATH>
  <CLICON_STREAM_URL>https://localhost</CLICON_STREAM_URL>
  <CLICON_STREAM_PUB>http://localhost/pub</CLICON_STREAM_PUB>
</config>
EOF

# RFC5277 NETCONF Event Notifications 
# using reportingEntity (rfc5277) not reporting-entity (rfc8040)
cat <<EOF > $fyang
     module example {
       namespace "http://example.com/event/1.0";
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

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err
fi
new "start backend -s init -f $cfg -y $fyang"
sudo $clixon_backend -s init -f $cfg -y $fyang # -D 1

if [ $? -ne 0 ]; then
    err
fi

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf
      
new "start restconf daemon"
sudo start-stop-daemon -S -q -o -b -x /www-data/clixon_restconf -d /www-data -c www-data -- -f $cfg  -y $fyang # -D 1

sleep 1

new "netconf event stream discovery RFC5277 Sec 3.2.5"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get><filter type="xpath" select="netconf/streams" xmlns="urn:ietf:params:xml:ns:netmod:notification"/></get></rpc>]]>]]>' '<rpc-reply><data><netconf><streams><stream><name>EXAMPLE</name><description>Example event stream</description><replay-support>false</replay-support></stream></streams></netconf></data></rpc-reply>]]>]]>'

new "netconf event stream discovery RFC8040 Sec 6.2"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get><filter type="xpath" select="restconf-state/streams" xmlns="urn:ietf:params:xml:ns:netmod:notification"/></get></rpc>]]>]]>' '<rpc-reply><data><restconf-state><streams><stream><name>EXAMPLE</name><description>Example event stream</description><replay-support>false</replay-support><access><encoding>xml</encoding><location>https://localhost/streams/EXAMPLE</location></access></stream></streams></restconf-state></data></rpc-reply>]]>]]>'

new "restconf event stream discovery RFC8040 Sec 6.2"
expectfn "curl -s -X GET http://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/streams" 0 '{"streams": {"stream": \[{"name": "EXAMPLE","description": "Example event stream","replay-support": false,"access": \[{"encoding": "xml","location": "https://localhost/streams/EXAMPLE"}\]}\]}'

new "restconf subscribe RFC8040 Sec 6.3, get location"
expectfn "curl -s -X GET http://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/streams/stream=EXAMPLE/access=xml/location" 0 '{"location": "https://localhost/streams/EXAMPLE"}'

# Restconf stream subscription RFC8040 Sec 6.3 - Native solution
new "restconf monitor event nonexist stream"
expectwait 'curl -s -X GET -H "Accept: text/event-stream" -H "Cache-Control: no-cache" -H "Connection: keep-alive" http://localhost/streams/NOTEXIST' 0 '<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-tag>invalid-value</error-tag><error-type>application</error-type><error-severity>error</error-severity><error-message>No such stream</error-message></error></errors>' 2

# Need manual testing
new "restconf monitor streams native NEEDS manual testing"
if false; then
    # url -H "Accept: text/event-stream" http://localhost/streams/EXAMPLE
    # Expect:
    # data: <notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>2018-10-21T19:22:11.381827</eventTime><event><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event></notification>
    #
    # data: <notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>2018-10-21T19:22:16.387228</eventTime><event><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event></notification>

new "restconf monitor event ok stream"
expectwait 'curl -s -X GET  -H "Accept: text/event-stream" -H "Cache-Control: no-cache" -H "Connection: keep-alive" http://localhost/streams/EXAMPLE' 0 'foo' 2
fi
# Restconf stream subscription RFC8040 Sec 6.3 - Nginx nchan solution
# Need manual testing
new "restconf monitor streams nchan NEEDS manual testing"
if false; then
    # url -H "Accept: text/event-stream" http://localhost/streams/EXAMPLE
    # Expect:
    echo foo
fi
# Netconf stream subscription
# Switch here since subscriptions takes time
if true; then

new "netconf EXAMPLE subscription"
expectwait "$clixon_netconf -qf $cfg -y $fyang" '<rpc><create-subscription><stream>EXAMPLE</stream></create-subscription></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' 5

new "netconf EXAMPLE subscription with simple filter"
expectwait "$clixon_netconf -qf $cfg -y $fyang" "<rpc><create-subscription><stream>EXAMPLE</stream><filter type=\"xpath\" select=\"event\"/></create-subscription></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' 5

new "netconf EXAMPLE subscription with filter classifier"
expectwait "$clixon_netconf -qf $cfg -y $fyang" "<rpc><create-subscription><stream>EXAMPLE</stream><filter type=\"xpath\" select=\"event[event-class='fault']\"/></create-subscription></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' 5

new "netconf NONEXIST subscription"
expectwait "$clixon_netconf -qf $cfg -y $fyang" '<rpc><create-subscription><stream>NONEXIST</stream></create-subscription></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-tag>invalid-value</error-tag><error-type>application</error-type><error-severity>error</error-severity><error-message>No such stream</error-message></rpc-error></rpc-reply>]]>]]>$' 5
fi

#new "netconf EXAMPLE subscription with replay"
#expectwait "$clixon_netconf -qf $cfg -y $fyang" '<rpc><create-subscription><stream>EXAMPLE</stream><startTime>2018-10-21T19:22:16</startTime><stopTime>2018-10-21T19:25:00</stopTime></create-subscription></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' 5

new "Kill restconf daemon"
sudo pkill -u www-data clixon_restconf

new "Kill backend"
# kill backend
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

# Check if still alive
pid=`pgrep clixon_backend`
if [ -n "$pid" ]; then
    sudo kill $pid
fi

rm -rf $dir
