#!/bin/bash
# Restconf basic functionality
# Assume http server setup, such as nginx described in apps/restconf/README.md
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
         description "state data for example application";
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
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get><filter type="xpath" select="netconf/streams" xmlns="urn:ietf:params:xml:ns:netmod:notification"/></get></rpc>]]>]]>' '<rpc-reply><data><netconf><streams><stream><name>NETCONF</name><description>default NETCONF event stream</description><replay-support>false</replay-support></stream></streams></netconf></data></rpc-reply>]]>]]>'

new "netconf event stream discovery RFC8040 Sec 6.2"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get><filter type="xpath" select="restconf-state/streams" xmlns="urn:ietf:params:xml:ns:netmod:notification"/></get></rpc>]]>]]>' '<rpc-reply><data><restconf-state><streams><stream><name>NETCONF</name><description>default NETCONF event stream</description><replay-support>false</replay-support><access><encoding>xml</encoding><location>/stream/NETCONF</location></access></stream></streams></restconf-state></data></rpc-reply>]]>]]>'

new "restconf event stream discovery RFC8040 Sec 6.2"
expectfn "curl -s -X GET http://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/streams" 0 '{"streams": {"stream": \[{"name": "NETCONF","description": "default NETCONF event stream","replay-support": false,"access": \[{"encoding": "xml","location": "/stream/NETCONF"}\]}\]}'

new "restconf subscribe RFC8040 Sec 6.3, get location"
expectfn "curl -s -X GET http://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/streams/stream=NETCONF/access=xml/location" 0 '{"location": "/stream/NETCONF"}'

new "netconf NETCONF subscription"
expectwait "$clixon_netconf -qf $cfg -y $fyang" '<rpc><create-subscription><stream>NETCONF</stream></create-subscription></rpc>]]>]]>' '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' 5

new "netconf NETCONF subscription with simple filter"
expectwait "$clixon_netconf -qf $cfg -y $fyang" "<rpc><create-subscription><stream>NETCONF</stream><filter type=\"xpath\" select=\"event\"/></create-subscription></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' 5

new "netconf NETCONF subscription with filter classifier"
expectwait "$clixon_netconf -qf $cfg -y $fyang" "<rpc><create-subscription><stream>NETCONF</stream><filter type=\"xpath\" select=\"event[event-class='fault']\"/></create-subscription></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]><notification xmlns="urn:ietf:params:xml:ns:netconf:notification:1.0"><eventTime>20' 5

#new "restconf monitor event stream RFC8040 Sec 6.3"
#XXX expectfn "curl -s -X GET http://localhost/stream/NETCONF" 0 ''

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

#rm -rf $dir
