#!/usr/bin/env bash
# Scaling/ performance tests
# State data only, in particular non-config lists (ie not state leafs on a config list)
# Restconf/Netconf/CLI
# ALso added two layers a/b to get extra depth (som caching can break)

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

# Number of list/leaf-list entries in file (cant be less than 2)
: ${perfnr:=1000}

# Number of requests made get/put
: ${perfreq:=10}

# time function (this is a mess to get right on freebsd/linux)
: ${TIMEFN:=time -p} # portability: 2>&1 | awk '/real/ {print $2}'

APPNAME=example

cfg=$dir/config.xml
fyang=$dir/$APPNAME.yang
fconfig=$dir/large.xml
fstate=$dir/state.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/example/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/example/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
</clixon-config>
EOF

cat <<EOF > $fyang
module $APPNAME{
   yang-version 1.1;
   prefix ex;
   namespace "urn:example:clixon";
   container interfaces {
    config false;
    list a{
      key "name";
      leaf name {
        type string;
      }
    container b{
    list interface {
      key "name";
      leaf name {
        type string;
      }
      leaf type {
        type string;
      }
      leaf enabled {
        type boolean;
        default true;
      }
      leaf status {
        type string;
      }
    }
}
}
  }
}
EOF

new "generate state file with $perfnr list entries"
echo -n "<interfaces xmlns=\"urn:example:clixon\"><a><name>foo</name><b>" > $fstate
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<interface><name>e$i</name><type>ex:eth</type><status>up</status></interface>" >> $fstate
done
echo "</b></a></interfaces>" >> $fstate

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend -s init -f $cfg -- -sS $fstate"
    start_backend -s init -f $cfg -- -sS $fstate
fi

new "waiting"
wait_backend

new "kill old restconf daemon"
sudo pkill -u $wwwuser -f clixon_restconf

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_restconf
exit
if false; then
new "generate 'large' config with $perfnr list entries"
echo -n "<rpc><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:example:clixon\"><a><name>foo</name><b>" > $fconfig
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<interface><name>e$i</name><type>ex:eth</type></interface>" >> $fconfig
done
echo "</b></a></interfaces></config></edit-config></rpc>]]>]]>" >> $fconfig

# Now take large config file and write it via netconf to candidate
new "netconf write large config"
expecteof_file "time -p $clixon_netconf -qf $cfg" 0 "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 2>&1 | awk '/real/ {print $2}'

# Now commit it from candidate to running 
new "netconf commit large config"
expecteof "time -p $clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 2>&1 | awk '/real/ {print $2}'
fi

# START actual tests
# Having a large db, get single entries many times
# NETCONF get
new "netconf get test single req"
sel="/ex:interfaces/ex:a[ex:name='foo']/ex:b/ex:interface[ex:name='e1']"
msg="<rpc><get><filter type=\"xpath\" select=\"$sel\" xmlns:ex=\"urn:example:clixon\"/></get></rpc>]]>]]>"
time -p expecteof "$clixon_netconf -qf $cfg" 0 "$msg" '^<rpc-reply><data><interfaces xmlns="urn:example:clixon"><a><name>foo</name><b><interface><name>e1</name><type>ex:eth</type><enabled>true</enabled><status>up</status></interface></b></a></interfaces></data></rpc-reply>]]>]]>$'

new "netconf get $perfreq single reqs"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    sel="/ex:interfaces/ex:a[ex:name='foo']/ex:b/ex:interface[ex:name='e$rnd']"
    echo "<rpc><get><filter type=\"xpath\" select=\"$sel\" xmlns:ex=\"urn:example:clixon\"/></get></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg > /dev/null; } 2>&1 | awk '/real/ {print $2}'

# RESTCONF get
#echo "curl -s -X GET http://localhost/restconf/data/example:interfaces/a=foo/b/interface=e1"
new "restconf get test single req"
time -p expecteq "$(curl -s -X GET http://localhost/restconf/data/example:interfaces/a=foo/b/interface=e1)" 0 '{"example:interface":[{"name":"e1","type":"ex:eth","enabled":true,"status":"up"}]}
' | awk '/real/ {print $2}'

new "restconf get $perfreq single reqs"
#echo "curl -sG http://localhost/restconf/data/ietf-interfaces:interfaces/interface=e0"
#curl -sG http://localhost/restconf/data/ietf-interfaces:interfaces/interface=e67

{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl -sG http://localhost/restconf/data/example:interfaces/a/b/interface=e$rnd > /dev/null
done } 2>&1 | awk '/real/ {print $2}'

if false; then
# CLI get
new "cli get test single req"
expectfn "$clixon_cli -1 -1f $cfg -l o show state xml interfaces a foo b interface e1" 0 '^<interface>
   <name>e1</name>
   <type>eth</type>
   <enabled>true</enabled>
   <status>up</status>
</interface>$'

new "cli get $perfreq single reqs"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    $clixon_cli -1 -f $cfg show state xml interfaces a b interface e$rnd > /dev/null
done } 2>&1 | awk '/real/ {print $2}'
fi
# Get config in one large get
new "netconf get large config"
{ time -p echo "<rpc><get> <filter type=\"xpath\" select=\"/ex:interfaces/ex:a[name='foo']/ex:b\" xmlns:ex=\"urn:example:clixon\"/></get></rpc>]]>]]>" | $clixon_netconf -qf $cfg  > /tmp/netconf; } 2>&1 | awk '/real/ {print $2}'

new "restconf get large config"
$TIMEFN curl -sG http://localhost/restconf/data/example:interfaces/a=foo/b 2>&1 | awk '/real/ {print $2}'

new "cli get large config"
$TIMEFN $clixon_cli -1f $cfg show state xml interfaces a foo b 2>&1 | awk '/real/ {print $2}'

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

# unset conditional parameters 
unset format
unset perfnr
unset perfreq


