#!/usr/bin/env bash
# Scaling/ performance tests
# State data only, in particular non-config lists (ie not state leafs on a config list)
# Restconf/Netconf/CLI
# Also added two layers a/b to get extra depth (som caching can break)
# Alternative, run as:
# sudo $clixon_backend -Fs init -f /var/tmp/./test_perf_state_only.sh/config.xml -- -siS /home/olof/tmp/state_100K.xml

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

# Number of list/leaf-list entries in file (cant be less than 2)
: ${perfnr:=20000}

# Number of requests made get/put
: ${perfreq:=10}

# time function (this is a mess to get right on freebsd/linux)
: ${TIMEFN:=time -p} # portability: 2>&1 | awk '/real/ {print $2}'
if ! $TIMEFN true; then err "A working time function" "'$TIMEFN' does not work"; fi

APPNAME=example

cfg=$dir/config.xml
fyang=$dir/$APPNAME.yang
fstate=$dir/state.xml

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
  $RESTCONFIG
</clixon-config>
EOF

# Note, there is a commented default statement below. It may be useful, bit for a
# clean performance setup, adding default values may be a fringe case?
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
/*            default true;  */
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

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then

    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

new "cli get large config"
# baseline on thinkpad i5-3320M CPU @ 2.60GHz and 500K entries: 39.71s
$TIMEFN $clixon_cli -1f $cfg show xpath /interfaces urn:example:clixon 2>&1 > /dev/null | awk '/real/ {print $2}'

# START actual tests
# Having a large db, get single entries many times
# NETCONF get
new "netconf get test single req"
sel="/ex:interfaces/ex:a[ex:name='foo']/ex:b/ex:interface[ex:name='e1']"
rpc=$(chunked_framing "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"$sel\" xmlns:ex=\"urn:example:clixon\"/></get></rpc>")
time -p expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "$rpc" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"urn:example:clixon\"><a><name>foo</name><b><interface><name>e1</name><type>ex:eth</type><status>up</status></interface></b></a></interfaces></data></rpc-reply>"

new "netconf get $perfreq single reqs"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    sel="/ex:interfaces/ex:a[ex:name='foo']/ex:b/ex:interface[ex:name='e$rnd']"
    rpc=$(chunked_framing "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"$sel\" xmlns:ex=\"urn:example:clixon\"/></get></rpc>")
    echo "$rpc"
done | $clixon_netconf -1qf $cfg > /dev/null; } 2>&1 | awk '/real/ {print $2}'

# RESTCONF get
#echo "curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:interfaces/a=foo/b/interface=e1"
new "restconf get test single req"
time -p expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:interfaces/a=foo/b/interface=e1)" 0 '{"example:interface":[{"name":"e1","type":"ex:eth","status":"up"}]}' | awk '/real/ {print $2}'

new "restconf get $perfreq single reqs"
#curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-interfaces:interfaces/interface=e67

{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:interfaces/a/b/interface=e$rnd > /dev/null
done } 2>&1 | awk '/real/ {print $2}'

if false; then
# CLI get
new "cli get test single req"
expectpart "$($clixon_cli -1 -1f $cfg -l o show state xml interfaces a foo b interface e1)" 0 '^<interface>
   <name>e1</name>
   <type>eth</type>
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
rpc=$(chunked_framing "<rpc $DEFAULTNS><get> <filter type=\"xpath\" select=\"/ex:interfaces/ex:a[name='foo']/ex:b\" xmlns:ex=\"urn:example:clixon\"/></get></rpc>")
{ time -p echo "$DEFAULTHELLO$rpc" | $clixon_netconf -qef $cfg  > /dev/null; } 2>&1 | awk '/real/ {print $2}'

new "restconf get large config"
$TIMEFN curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:interfaces/a=foo/b 2>&1 | awk '/real/ {print $2}'

new "cli get large config"
$TIMEFN $clixon_cli -1f $cfg show state xml 2>&1 | awk '/real/ {print $2}'

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

rm -rf $dir

new "endtest"
endtest
