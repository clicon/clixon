#!/usr/bin/env bash
# Restconf RFC8040 Appendix A and B "jukebox" example
# For pagination / scaling I-D activity
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fexample=$dir/example-module.yang
fstate=$dir/mystate.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
</clixon-config>
EOF

cat <<'EOF' > $dir/startup_db
<config>
     <admins xmlns="http://example.com/ns/example-module">
       <admin>
         <name>Alice</name>
         <access>permit</access>
         <email-address>alice@example.com</email-address>
         <password>$0$1543</password>
         <preference>
           <number>1</number>
           <number>2</number>
         </preference>
         <skill>
           <name>Customer Service</name>
           <rank>99</rank>
         </skill>
         <skill>
           <name>Problem Solving</name>
           <rank>90</rank>
         </skill>
       </admin>
       <admin>
         <name>Bob</name>
         <access>limited</access>
         <email-address>bob@example.com</email-address>
         <password>$0$2789</password>
         <preference>
           <number>2</number>
           <number>3</number>
         </preference>
         <skill>
           <name>Conflict Resolution</name>
           <rank>93</rank>
         </skill>
         <skill>
           <name>Management</name>
           <rank>23</rank>
         </skill>
         <skill>
           <name>Organization</name>
           <rank>44</rank>
         </skill>
         <skill>
           <name>Problem Solving</name>
           <rank>98</rank>
         </skill>
       </admin>
       <admin>
         <name>Joe</name>
         <access>permit</access>
         <email-address>joe@example.com</email-address>
         <password>$0$6523</password>
         <preference>
           <number>1</number>
           <number>4</number>
         </preference>
         <skill>
           <name>Management</name>
           <rank>96</rank>
         </skill>
         <skill>
           <name>Collaboration</name>
           <rank>92</rank>
         </skill>
       </admin>
       <admin>
         <name>Frank</name>
         <access>deny</access>
         <email-address>frank@example.com</email-address>
         <password>$0$4030</password>
         <preference>
           <number>5</number>
           <number>9</number>
         </preference>
         <skill>
           <name>Organization</name>
           <rank>90</rank>
         </skill>
         <skill>
           <name>Negotiation</name>
           <rank>80</rank>
         </skill>
       </admin>
       <admin>
         <name>Tom</name>
         <access>permit</access>
         <email-address>tom@example.com</email-address>
         <password>$0$2376</password>
         <preference>
           <number>2</number>
           <number>5</number>
         </preference>
         <skill>
           <name>Adaptability.</name>
           <rank>98</rank>
         </skill>
         <skill>
           <name>Active Listening</name>
           <rank>85</rank>
         </skill>
       </admin>
     </admins>
     <rulebase  xmlns="http://example.com/ns/example-module">
       <rule>
         <name>SvrA-http</name>
         <match>92.0.2.0/24</match>
         <action>forwarding</action>
       </rule>
       <rule>
         <name>SvrA-ftp</name>
         <match>203.0.113.1/32</match>
         <action>forwarding</action>
       </rule>
       <rule>
         <name>p2p</name>
         <match>p2p</match>
         <action>logging</action>
       </rule>
       <rule>
         <name>any</name>
         <match>any</match>
         <action>logging</action>
       </rule>
       <rule>
         <name>SvrA-tcp</name>
         <match>80</match>
         <action>forwarding</action>
       </rule>
     </rulebase>
     <prefixes  xmlns="http://example.com/ns/example-module">
       <prefix-list>
         <ip-prefix>10.0.0.0/8</ip-prefix>
         <masklength-lower>17</masklength-lower>
         <masklength-upper>18</masklength-upper>
       </prefix-list>
       <prefix-list>
         <ip-prefix>2000:1::/48</ip-prefix>
         <masklength-lower>48</masklength-lower>
         <masklength-upper>48</masklength-upper>
       </prefix-list>
       <prefix-list>
         <ip-prefix>2000:2::/48</ip-prefix>
         <masklength-lower>48</masklength-lower>
         <masklength-upper>48</masklength-upper>
       </prefix-list>
       <prefix-list>
         <ip-prefix>2000:3::/48</ip-prefix>
         <masklength-lower>16</masklength-lower>
         <masklength-upper>16</masklength-upper>
       </prefix-list>
       <prefix-list>
         <ip-prefix>::/0</ip-prefix>
         <masklength-lower>0</masklength-lower>
         <masklength-upper>128</masklength-upper>
       </prefix-list>
     </prefixes>
</config>
EOF

cat<<EOF > $fstate
  <admins xmlns="http://example.com/ns/example-module">
    <admin>
      <name>Alice</name>
      <status>Available</status>
    </admin>
    <admin>
      <name>Bob</name>
      <status>Busy</status>
    </admin>
    <admin>
      <name>Joe</name>
      <status>Do Not Disturb</status>
    </admin>	 
    <admin>
      <name>Frank</name>
      <status>Offline</status>
    </admin>
    <admin>
      <name>Tom</name>
      <status>Do Not Disturb</status>
    </admin>
  </admins>
     <device-logs  xmlns="http://example.com/ns/example-module">
       <device-log>
         <device-id>Cloud-IoT-Device-A</device-id>
         <time-received>2020-07-08T12:38:32Z</time-received>
         <time-generated>2020-07-08T12:37:12Z</time-generated>
         <message>Upload contains 6 datapoints</message>
       </device-log>
       <device-log>
         <device-id>Cloud-IoT-Device-B</device-id>
         <time-received>2020-07-08T16:20:54Z</time-received>
         <time-generated>2020-07-08T16:20:14Z</time-generated>
         <message>Upload successful</message>
       </device-log>
       <device-log>
         <device-id>Cloud-IoT-Device-C</device-id>
         <time-received>2020-07-08T17:30:34Z</time-received>
         <time-generated>2020-07-08T17:30:12Z</time-generated>
         <message>Receive a configuration update</message>
       </device-log>
       <device-log>
         <device-id>Cloud-IoT-Device-D</device-id>
         <time-received>2020-07-08T18:40:13Z</time-received>
         <time-generated>2020-07-08T18:40:00Z</time-generated>
         <message>Keep-alive ping sent to server</message>
       </device-log>
       <device-log>
         <device-id>Cloud-IoT-Device-E</device-id>
         <time-received>2020-07-08T19:48:34Z</time-received>
         <time-generated>2020-07-08T19:48:00Z</time-generated>
         <message>Uploading data to DataPoint</message>
       </device-log>
     </device-logs>
     <audit-logs  xmlns="http://example.com/ns/example-module">
       <audit-log>
         <source-ip>192.168.0.92</source-ip>
         <log-creation>2020-11-01T06:47:59Z</log-creation>
         <request>User-logged-out</request>
         <outcome>true</outcome>
       </audit-log>
       <audit-log>
         <source-ip>192.168.0.92</source-ip>
         <log-creation>2020-11-01T06:49:03Z</log-creation>
         <request>User-logged-in</request>
         <outcome>true</outcome>
       </audit-log>
       <audit-log>
         <source-ip>192.168.0.92</source-ip>
         <log-creation>2020-11-01T06:51:34Z</log-creation>
         <request>Patron-card-viewed</request>
         <outcome>false</outcome>
       </audit-log>
       <audit-log>
         <source-ip>192.168.0.92</source-ip>
         <log-creation>2020-11-01T06:53:01Z</log-creation>
         <request>User-logged-out</request>
         <outcome>true</outcome>
       </audit-log>
       <audit-log>
         <source-ip>192.168.0.92</source-ip>
         <log-creation>2020-11-01T06:56:22Z</log-creation>
         <request>User-logged-in</request>
         <outcome>false</outcome>
       </audit-log>
     </audit-logs>
EOF

# Common example-module spec (fexample must be set)
. ./example_module.sh

new "test params: -f $cfg -s startup -- -sS $fstate"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure

    new "start backend -s startup -f $cfg -- -sS $mystate"
    start_backend -s startup -f $cfg -- -sS $fstate
fi

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg

    new "wait restconf"
    wait_restconf
fi

# draft-wwlh-netconf-list-pagination-nc-00.txt
new "C.1. 'count' Parameter NETCONF"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc message-id=\"101\" xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><get-pageable-list xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-list-pagination\"><datastore xmlns:ds=\"urn:ietf:params:xml:ns:yang:ietf-datastores\">ds:running</datastore><list-target xmlns:exm=\"http://example.com/ns/example-module\">/exm:admins/exm:admin[exm:name='Bob']/exm:skill</list-target><count>2</count></get-pageable-list></rpc>]]>]]>" '<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="101"><pageable-list xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-list-pagination"><skill xmlns="http://example.com/ns/example-module"><name>Conflict Resolution</name><rank>93</rank></skill><skill xmlns="http://example.com/ns/example-module"><name>Management</name><rank>23</rank></skill></pageable-list></rpc-reply>]]>]]>$'

new "C.2. 'skip' Parameter NETCONF"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc message-id=\"101\" xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><get-pageable-list xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-list-pagination\"><datastore xmlns:ds=\"urn:ietf:params:xml:ns:yang:ietf-datastores\">ds:running</datastore><list-target xmlns:exm=\"http://example.com/ns/example-module\">/exm:admins/exm:admin[exm:name='Bob']/exm:skill</list-target><count>2</count><skip>2</skip></get-pageable-list></rpc>]]>]]>" '<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="101"><pageable-list xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-list-pagination"><skill xmlns="http://example.com/ns/example-module"><name>Organization</name><rank>44</rank></skill><skill xmlns="http://example.com/ns/example-module"><name>Problem Solving</name><rank>98</rank></skill></pageable-list></rpc-reply>]]>]]>$'

# CLI
# XXX This relies on a very specific clispec command: need a more generic test
new "cli show"
expectpart "$($clixon_cli -1 -f $cfg -l o show pagination)" 0 "<skill xmlns=\"http://example.com/ns/example-module\"><name>Conflict Resolution</name><rank>93</rank></skill>" "<skill xmlns=\"http://example.com/ns/example-module\"><name>Management</name><rank>23</rank></skill>" --not-- "<skill xmlns=\"http://example.com/ns/example-module\"><name>Organization</name><rank>44</rank></skill>"

# draft-wwlh-netconf-list-pagination-rc-00.txt
#new "A.1. 'count' Parameter RESTCONF"
#expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang.collection+xml" $RCPROTO://localhost/restconf/data/example-module:get-list-pagination/library/artist=Foo%20Fighters/album/?count=2)" 0  "HTTP/1.1 200 OK" "application/yang.collection+xml" '<collection xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-collection"><album xmlns="http://example.com/ns/example-jukebox"><name>Crime and Punishment</name><year>1995</year></album><album xmlns="http://example.com/ns/example-jukebox"><name>One by One</name><year>2002</year></album></collection>'

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

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
