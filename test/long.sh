#!/usr/bin/env bash
# Long-time test with restconf and get/sets
# for callgrind:
# Run add 100 4 times

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Number of list/leaf-list entries in file
: ${perfnr:=5000}

# Number of requests made get/put
: ${perfreq:=100}

# Which format to use as datastore format internally
: ${format:=xml}

APPNAME=example

cfg=$dir/scaling-conf.xml
fyang=$dir/scaling.yang
fconfig=$dir/large.xml

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

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
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  $RESTCONFIG
</clixon-config>
EOF

sudo callgrind_control -i off

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

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

new "generate 'large' config with $perfnr list entries"
echo -n "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\">" > $fconfig
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<y><a>$i</a><b>$i</b></y>" >> $fconfig
done
echo "</x></config></edit-config></rpc>]]>]]>" >> $fconfig

# Now take large config file and write it via netconf to candidate
new "netconf write large config"
expecteof_file "/usr/bin/time -f %e $clixon_netconf -qf $cfg" 0 "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Now commit it from candidate to running 
new "netconf commit large config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#  Zero all event counters
#sudo callgrind_control -i on
#sudo callgrind_control -z

while [ 1 ] ; do
    new "restconf add $perfreq small config"

time -p    for (( i=0; i<$perfreq; i++ )); do
#echo "i $i"
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' http://localhost/restconf/data/scaling:x/y=$rnd  -d '{"scaling:y":{"a":"'$rnd'","b":"'$rnd'"}}'
done

done
new "restconf get $perfreq small config"
time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json'http://localhost/restconf/data/scaling:x/y=$rnd,42 > /dev/null
done
done

new "Kill restconf daemon"
stop_restconf 

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=`pgrep -u root -f clixon_backend`
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
fi

# Set by restconf_config
unset RESTCONFIG

rm -rf $dir
