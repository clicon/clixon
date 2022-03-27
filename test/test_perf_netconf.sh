#!/usr/bin/env bash
# Scaling/ performance tests
# CLI/Netconf/Restconf
# Lists (and leaf-lists)
# Add, get and delete entries

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
# time function (this is a mess to get right on freebsd/linux)
: ${TIMEFN:=time -p} # portability: 2>&1 | awk '/real/ {print $2}'
if ! $TIMEFN true; then err "A working time function" "'$TIMEFN' does not work"; fi

APPNAME=example

cfg=$dir/perf-netconf-conf.xml
fyang=$dir/scaling.yang
fconfig=$dir/large.xml
fconfigonly=$dir/config.xml # only config for test
ftest=$dir/test.xml
fconfig2=$dir/large2.xml # leaf-list
foutput=$dir/output.xml

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

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
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
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
</clixon-config>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend -s init -f $cfg -- -s"
    start_backend -s init -f $cfg -- -s
fi

new "waiting"
wait_backend

# Check this later with committed data
new "generate config with $perfnr list entries"
echo -n "<x xmlns=\"urn:example:clixon\">" > $fconfigonly
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<y><a>$i</a><b>$i</b></y>" >> $fconfigonly
done
echo -n "</x>" >> $fconfigonly # No CR

rpc="<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>"
rpc+="$(cat $fconfigonly)"
rpc+="</config></edit-config></rpc>"

echo -n "$DEFAULTHELLO" > $fconfig
echo "$(chunked_framing "$rpc")" >> $fconfig

# Now take large config file and write it via netconf to candidate
new "test time exists"
expectpart "$(time -p ls)" 0 

new "netconf write large config"
expecteof_file "time -p $clixon_netconf -qef $cfg" 0 "$fconfig" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>$" 2>&1 | awk '/real/ {print $2}'

# Here, there are $perfnr entries in candidate

# Now commit it from candidate to running 
new "netconf commit large config"
expecteof_netconf "time -p $clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" 2>&1 | awk '/real/ {print $2}'

new "Check running-db contents"
rpc=$(chunked_framing "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>")
echo "$DEFAULTHELLO$rpc" | $clixon_netconf -qef $cfg > $foutput

rpc="<rpc-reply $DEFAULTNS><data>"
rpc+="$(cat $fconfigonly)"
rpc+="</data></rpc-reply>"
echo "$(chunked_framing "$rpc")" >> $ftest

# Create a file to compare with
#echo -n "<rpc-reply $DEFAULTNS><data>" > $ftest
#cat $fconfigonly >> $ftest
#echo -n "</data></rpc-reply>]]>]]>" >> $ftest

ret=$(diff $ftest $foutput)
if [ $? -ne 0 ]; then
    err1 "Matching running-db with $fconfigonly"
fi	

# Now commit it again from candidate (validation takes time when
# comparing to existing)

# Having a large db, get and put single entries many times
# Note same entries in the range alreay there, db has same size

# NETCONF get 1 key index
# Note this is done by streaming input into one single netconf client. it is much
# slower if it is started and stopped for each request. (next)
new "netconf get $perfreq small config 1 key index"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    rpc=$(chunked_framing "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/ex:x/ex:y[ex:a=$rnd]\" xmlns:ex=\"urn:example:clixon\"/></get-config></rpc>")
    echo "$rpc"
done | $clixon_netconf -Hqef $cfg > /dev/null; } 2>&1 | awk '/real/ {print $2}'

new "netconf get $perfreq small config 1 key index start/stop"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    rpc=$(chunked_framing "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/ex:x/ex:y[ex:a=$rnd]\" xmlns:ex=\"urn:example:clixon\"/></get-config></rpc>")
    echo "$DEFAULTHELLO$rpc"    | $clixon_netconf -qef $cfg > /dev/null; 
done
}  2>&1 | awk '/real/ {print $2}'

# NETCONF get 1 key and one non-key index
new "netconf get $perfreq small config 1 key + 1 non-key index"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    rpc=$(chunked_framing "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/ex:x/ex:y[ex:a=$rnd][ex:b=$rnd]\" xmlns:ex=\"urn:example:clixon\"/></get-config></rpc>")
    echo "$rpc"
done | $clixon_netconf -Hqef $cfg > /dev/null; } 2>&1 | awk '/real/ {print $2}'

# NETCONF add
new "netconf add $perfreq small config"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    rpc=$(chunked_framing "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>")
    echo "$rpc"
done | $clixon_netconf -Hqef $cfg > /dev/null; } 2>&1 | awk '/real/ {print $2}'

# Instead of many small entries, get one large in netconf and restconf
# cli?
new "netconf get large config"
expecteof_netconf "time -p $clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><y><a>0</a><b>0</b></y><y><a>1</a><b>1</b></y><y><a>2</a><b>2</b></y><y><a>3</a><b>3</b></y>" "" 2>&1 | awk '/real/ {print $2}'

# Delete entries (last since entries are removed from db)
new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf delete $perfreq small config"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    rpc=$(chunked_framing "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><y nc:operation=\"delete\"><a>$rnd</a></y></x></config></edit-config></rpc>")
    echo "$rpc"
done | $clixon_netconf -Hqef $cfg  > /dev/null; }  2>&1 | awk '/real/ {print $2}'

#new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Now do leaf-lists istead of leafs
new "generate leaf-list config"
rpc="<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><x xmlns=\"urn:example:clixon\">"
for (( i=0; i<$perfnr; i++ )); do  
    rpc+="<c>$i</c>"
done
rpc+="</x></config></edit-config></rpc>"

echo -n "$DEFAULTHELLO" > $fconfig2
echo "$(chunked_framing "$rpc")" >> $fconfig2

new "netconf replace large list-leaf config"
expecteof_file "time -p $clixon_netconf -qef $cfg" 0 "$fconfig2" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>$" 2>&1 | awk '/real/ {print $2}'

new "netconf commit large leaf-list config"
expecteof_netconf "time -p $clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" 2>&1 | awk '/real/ {print $2}'

new "netconf add $perfreq small leaf-list config"
{ time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    rpc=$(chunked_framing "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><c>$rnd</c></x></config></edit-config></rpc>")
    echo "$rpc"
done | $clixon_netconf -Hqef $cfg > /dev/null; } 2>&1 | awk '/real/ {print $2}'

new "netconf add small leaf-list config"
expecteof_netconf "time -p $clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><c>x</c></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" 2>&1 | awk '/real/ {print $2}'

new "netconf commit small leaf-list config"
expecteof_netconf "time -p $clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" 2>&1 | awk '/real/ {print $2}'

new "netconf get large leaf-list config"
expecteof_netconf "time -p $clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><c>0</c><c>1</c>" ""

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

# unset conditional parameters 
unset format
unset perfnr
unset perfreq

new "endtest"
endtest
