#!/usr/bin/env bash
# Scaling/ performance tests for non-ssl RESTCONF
# Lists (and leaf-lists)
# Add, get and delete entries

# Override default to use http/1.1, comment to use https/2
HAVE_LIBNGHTTP2=false
RCPROTO=http

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

# Number of list/leaf-list entries in file
: ${perfnr:=20000}

# Number of requests made get/put
: ${perfreq:=10}

# time function (this is a mess to get right on freebsd/linux)
# -f %e gives elapsed wall clock time but is not available on all systems
# so we use time -p for POSIX compliance and awk to get wall clock time
# Note sometimes time -p is used and sometimes $TIMEFN, cant get it to work same everywhere
: ${TIMEFN:=time -p} # portability: 2>&1 | awk '/real/ {print $2}'
if ! $TIMEFN true; then err "A working time function" "'$TIMEFN' does not work"; fi

APPNAME=example

cfg=$dir/scaling-conf.xml
fyang=$dir/scaling.yang
fdataxml=$dir/large.xml # dataxml 
ftest=$dir/test.xml
fdataxml2=$dir/large2.xml # leaf-list XXX use restconf
foutput=$dir/output.xml
foutput2=$dir/output2.xml

cat <<EOF > $fyang
module scaling{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   container x {
    list y {
      key "a";
      leaf a {
        type int32;
      }
      leaf b {
        type int32;
      }
    }
    leaf-list c {
       type string;
    }
  }
}
EOF

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/example/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/example/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_LOG_STRING_LIMIT>128</CLICON_LOG_STRING_LIMIT>
  $RESTCONFIG
</clixon-config>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi

#    sudo pkill clixon_backend # extra
#    sleep 1    

    new "start backend -s init -f $cfg -- -s"
    start_backend -s init -f $cfg -- -s
fi

new "waiting"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

# Check this later with committed data
new "generate config with $perfnr list entries to $fdataxml"
echo -n "<x xmlns=\"urn:example:clixon\">" > $fdataxml
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<y><a>$i</a><b>$i</b></y>" >> $fdataxml
done
echo -n "</x>" >> $fdataxml # No CR

# Now take large config file and write it via netconf to candidate
new "test time exists"
expectpart "$(time -p ls)" 0 

# Use PUT so it can be repeated
new "restconf PUT large initial config"
echo "curl $CURLOPTS -X PUT -H \"Content-Type: application/yang-data+xml\" $RCPROTO://localhost/restconf/data/scaling:x -d @$fdataxml"
expectpart "$(time -p curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data/scaling:x -d @$fdataxml)" 0 "HTTP/$HVER 20"

new "Check running-db contents"
curl $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data?content=config > $foutput
r=$?
if [ $r -ne 0 ]; then
    err1 "retval 0" $r
fi

# Remove Content-Length line (depends on size)
# Note: do not use sed -i since it is not portable between gnu and bsd
sed '/Content-Length:/d' $foutput > $foutput2 && mv $foutput2 $foutput
sed '/content-length:/d' $foutput > $foutput2 && mv $foutput2 $foutput
# Remove (nginx) web-server specific lines
sed '/Server:/d' $foutput > $foutput2 && mv $foutput2 $foutput
sed '/Date:/d' $foutput > $foutput2 && mv $foutput2 $foutput
sed '/Transfer-Encoding:/d' $foutput > $foutput2 && mv $foutput2 $foutput
sed '/Connection:/d' $foutput > $foutput2 && mv $foutput2 $foutput

# Create a file to compare with
if ${HAVE_LIBNGHTTP2}; then
    if [ ${HAVE_HTTP1} -a ${RCPROTO} = http ]; then
	# Add 101 switch protocols for http 1->2 upgrade
	echo "HTTP/1.1 101 Switching Protocols" > $ftest
        echo "Upgrade: h2c" >> $ftest
	echo "" >> $ftest
	echo "HTTP/$HVER 200 " >> $ftest
    else
	echo "HTTP/$HVER 200 " > $ftest
    fi
else
    echo "HTTP/$HVER 200 OK" > $ftest
fi
echo "Content-Type: application/yang-data+xml" >> $ftest
echo "Cache-Control: no-cache" >> $ftest
echo "">> $ftest
echo -n "<data>">> $ftest
cat $fdataxml >> $ftest
echo "</data>" >> $ftest

ret=$(diff -i $ftest $foutput)
if [ $? -ne 0 ]; then
    echo "diff -i $ftest $foutput"
    err1 "Matching running-db with $fdataxml"
fi	

# RESTCONF get
new "restconf get $perfreq small config 1 key index"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/scaling:x/y=$rnd > /dev/null
done } 2>&1 | awk '/real/ {print $2}'

# RESTCONF put
# Reference:
# i686 format=xml perfnr=10000/100 time: 38/29s 20190425  WITH/OUT startup copying
# i686 format=tree perfnr=10000/100 time: 72/64s 20190425 WITH/OUT startup copying
new "restconf add $perfreq small config"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl $CURLOPTS -X PUT $RCPROTO://localhost/restconf/data/scaling:x/y=$rnd  -d '{"scaling:y":{"a":"'$rnd'","b":"'$rnd'"}}'
done }  2>&1 | awk '/real/ {print $2}'

new "restconf get large config"
# XXX for some reason cannot expand $TIMEFN next two tests, need keep variable?
$TIMEFN curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data 2>&1 > /dev/null | awk '/real/ {print $2}'

# Delete entries (last since entries are removed from db)
# netconf
new "cli delete $perfreq small config"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    $clixon_cli -1 -f $cfg delete x y $rnd 
done } 2>&1 | awk '/real/ {print $2}'

#new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# XXX This takes time
# 18.69 without startup feature
# 21.98 with startup
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/scaling:x/y=$rnd
done > /dev/null; } 2>&1 | awk '/real/ {print $2}'

# Now do leaf-lists istead of leafs
new "generate config with $perfnr leaf-lists to $fdataxml2"
echo -n "<x xmlns=\"urn:example:clixon\">" > $fdataxml2
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<c>$i</c>" >> $fdataxml2
done
echo -n "</x>" >> $fdataxml2 # No CR

new "restconf replace large list-leaf config"
expectpart "$(time -p curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data/scaling:x -d @$fdataxml2)" 0 "HTTP/$HVER 20"

new "netconf add $perfreq small leaf-list config"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    echo "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><c>$rnd</c></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg > /dev/null; } 2>&1 | awk '/real/ {print $2}'

new "netconf add small leaf-list config"
expecteof "time -p $clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><c>x</c></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$" 2>&1 | awk '/real/ {print $2}'

new "netconf commit small leaf-list config"
expecteof "time -p $clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$" 2>&1 | awk '/real/ {print $2}'

new "netconf get large leaf-list config"
expecteof "time -p $clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><c>0</c><c>1</c>" 2>&1 | awk '/real/ {print $2}'

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

# Set by restconf_config
unset RESTCONFIG
unset HAVE_LIBNGHTTP2
unset RCPROTO

# unset conditional parameters 
unset format
unset perfnr
unset perfreq
unset ret

new "endtest"
endtest
