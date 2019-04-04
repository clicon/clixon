#!/bin/bash
# Long-time test with restconf and get/sets
# for callgrind:
# Run add 100 4 times

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Number of list/leaf-list entries in file
: ${perfnr:=1000}

# Number of requests made get/put
: ${perfreq:=100}

APPNAME=example

cfg=$dir/scaling-conf.xml
fyang=$dir/scaling.yang
fconfig=$dir/large.xml

cat <<EOF > $fyang
module scaling{
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
    leaf-list c {
       type string;
    }
  }
}
EOF

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>scaling</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
</clixon-config>
EOF

new "test params: -f $cfg -y $fyang"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend -s init -f $cfg -y $fyang"
    start_backend -s init -f $cfg -y $fyang
fi

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon"
start_restconf -f $cfg -y $fyang

new "waiting"
sleep $RCWAIT

while [ 1 ] ; do
    new "restconf add $perfreq small config"
    time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl -s -X PUT http://localhost/restconf/data/scaling:x/y=$rnd  -d '{"scaling:y":{"a":"'$rnd'","b":"'$rnd'"}}'
done

new "restconf get $perfreq small config"
time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl -sG http://localhost/restconf/data/scaling:x/y=$rnd,$rnd > /dev/null
done
done

new "Kill restconf daemon"
stop_restconf 

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
