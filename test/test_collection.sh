#!/usr/bin/env bash
# Restconf RFC8040 Appendix A and B "jukebox" example
# For collection / scaling activity
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fjukebox=$dir/example-jukebox.yang

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
</clixon-config>
EOF

cat <<EOF > $dir/startup_db
<config>
<jukebox xmlns="http://example.com/ns/example-jukebox">
  <library>
    <artist>
      <name>Foo Fighters</name>
      <album xmlns="http://example.com/ns/example-jukebox">
        <name>Crime and Punishment</name>
        <year>1995</year>
      </album>
      <album xmlns="http://example.com/ns/example-jukebox">
        <name>One by One</name>
        <year>2002</year>
      </album>
      <album xmlns="http://example.com/ns/example-jukebox">
        <name>The Color and the Shape</name>
        <year>1997</year>
      </album>
      <album xmlns="http://example.com/ns/example-jukebox">
        <name>There is Nothing Left to Loose</name>
        <year>1999</year>
      </album>
      <album xmlns="http://example.com/ns/example-jukebox">
        <name>White and Black</name>
        <year>1998</year>
      </album>
    </artist>
  </library>
</jukebox>
</config>
EOF

# Common Jukebox spec (fjukebox must be set)
. ./jukebox.sh

new "test params: -f $cfg -- -s" # XXX: -sS state file

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f "$cfg"
fi

new "waiting"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg

    new "waiting"
    wait_restconf
fi

new "C.1. 'count' Parameter RESTCONF"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang.collection+xml" $RCPROTO://localhost/restconf/data/example-jukebox:jukebox/library/artist=Foo%20Fighters/album/?count=2)" 0  "HTTP/1.1 200 OK" "application/yang.collection+xml" '<collection xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-collection"><album xmlns="http://example.com/ns/example-jukebox"><name>Crime and Punishment</name><year>1995</year></album><album xmlns="http://example.com/ns/example-jukebox"><name>One by One</name><year>2002</year></album></collection>'

new "C.1. 'count' Parameter NETCONF"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc netconf:message-id=\"101\" xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><get-collection xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-collection\"><datastore>running</datastore><module-name>example-jukebox</module-name><list-target>/example-jukebox:jukebox/library/artist=Foo Fighters/album</list-target><count>2</count></get-collection></rpc>]]>]]>" '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" netconf:message-id="101"><collection xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-collection"><album xmlns="http://example.com/ns/example-jukebox"><name>Crime and Punishment</name><year>1995</year></album><album xmlns="http://example.com/ns/example-jukebox"><name>One by One</name><year>2002</year></album></collection></rpc-reply>]]>]]>$'

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
