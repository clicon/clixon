#!/usr/bin/env bash
# Test restconf :startup
# RFC 8040 Sec 1.4 says:
# the NETCONF server supports :startup, the RESTCONF server MUST
#   automatically update the non-volatile startup configuration
#   datastore, after the "running" datastore has been altered as a
#   consequence of a RESTCONF edit operation.
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/example.yang

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ip;
   container x {
    list y {
      key "a";
      leaf a {
        type string;
      }
      leaf b {
        type string;
      }
    }
  }
}
EOF

# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  $RESTCONFIG
</clixon-config>
EOF

function testrun(){
    option=$1

    new "test params: -f $cfg -y $fyang $option"
    if [ $BE -ne 0 ]; then
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s init -f $cfg -y $fyang $option"
	start_backend -s init -f $cfg -y $fyang $option
    fi
    
    new "waiting"
    wait_backend
    
    new "kill old restconf daemon"
    stop_restconf_pre
    
    new "start restconf daemon"
    start_restconf -f $cfg -y $fyang $option
    
    new "waiting"
    wait_restconf

    new "restconf put 42"
    expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example:x/y=42 -d '{"example:y":{"a":"42","b":"42"}}')" 0 "HTTP/1.1 201 Created"

    new "restconf put 99"
    expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example:x/y=99 -d '{"example:y":{"a":"99","b":"99"}}')" 0 "HTTP/1.1 201 Created"

    new "restconf post 123"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example:x -d '{"example:y":{"a":"123","b":"123"}}')" 0 "HTTP/1.1 201 Created"

    new "restconf delete 42"
    expectpart "$(curl $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/example:x/y=42)" 0 "HTTP/1.1 204 No Content"

    new "Kill restconf daemon"
    stop_restconf 

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

# clear startup
sudo rm -f $dir/startup_db;

new "Run with startup option, check running is copied"
testrun "-o CLICON_FEATURE=ietf-netconf:startup"

new "Check running and startup exists and are same"
if [ ! -f $dir/startup_db ]; then
    err "startup should exist but does not"
fi

d=$(sudo diff $dir/startup_db $dir/running_db)
if [ -n "$d" ]; then
    err "running and startup should be equal" "$d"
fi

# clear startup
sudo rm -f $dir/startup_db; 

new "Run without startup option, check running is not copied"
testrun ""

new "Check startup is empty"
if [ -f $dir/startup_db ]; then
    err "startup should not exist"
fi

rm -rf $dir
