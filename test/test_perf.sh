#!/bin/bash
# Scaling/ performance tests

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

# Number of list/leaf-list entries in file
: ${perfnr:=10000}

# Number of requests made get/put
: ${perfreq:=100}

APPNAME=example

cfg=$dir/scaling-conf.xml
fyang=$dir/scaling.yang
fconfig=$dir/large.xml
fconfig2=$dir/large2.xml


cat <<EOF > $fyang
module scaling{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ip;
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
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>scaling</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/example/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/example/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_CLI_GENMODEL_TYPE>VARS</CLICON_CLI_GENMODEL_TYPE>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
</clixon-config>
EOF

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi
fi

# First generate large XML file
# Use it latter to generate startup-db in xml, tree formats
tmpx=$dir/tmp.xml
new "generate large startup config ($tmpx) with $perfnr entries"
echo -n "<config><x xmlns=\"urn:example:clixon\">" > $tmpx
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<y><a>$i</a><b>$i</b></y>" >> $tmpx
done
echo "</x></config>" >> $tmpx

if false; then
# Then generate large JSON file (cant translate namespace - long story)
tmpj=$dir/tmp.json
new "generate large startup config ($tmpj) with $perfnr entries"
echo -n '{"config": {"scaling:x":{"y":[' > $tmpj
for (( i=0; i<$perfnr; i++ )); do  
    if [ $i -ne 0 ]; then
	echo -n ",{\"a\":$i,\"b\":$i}" >> $tmpj
    else
	echo -n "{\"a\":$i,\"b\":$i}" >> $tmpj
    fi

done
echo "]}}}" >> $tmpj
fi

# Loop over mode and format
for mode in startup running; do
    file=$dir/${mode}_db
    for format in tree xml; do # json - something w namespaces
	sudo rm -f $file
	sudo touch $file
	sudo chmod 666 $file
	case $format in
	    xml)
		echo "cp $tmpx $file"
		cp $tmpx $file
	    ;;
	    json)
		cp $tmpj $file
	    ;;
	    tree)
		echo "clixon_util_datastore -d ${mode} -f tree -y $fyang -b $dir -x $tmpx put create"

		clixon_util_datastore -d ${mode} -f tree -y $fyang -b $dir -x $tmpx put create
	    ;;
	esac
	new "Startup format: $format mode:$mode"
#	echo "time sudo $clixon_backend -F1 -D $DBG -s $mode -f $cfg -y $fyang -o CLICON_XMLDB_FORMAT=$format"
	# Cannot use start_backend here due to expected error case
{ time -p sudo $clixon_backend -F1 -D $DBG -s $mode -f $cfg -y $fyang -o CLICON_XMLDB_FORMAT=$format 2> /dev/null; } 2>&1 | awk '/real/ {print $2}'

    done
done

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

new "generate 'large' config with $perfnr list entries"
echo -n "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\">" > $fconfig
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<y><a>$i</a><b>$i</b></y>" >> $fconfig
done
echo "</x></config></edit-config></rpc>]]>]]>" >> $fconfig

# Now take large config file and write it via netconf to candidate
new "netconf write large config"
expecteof_file "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Here, there are $perfnr entries in candidate
new "netconf write large config again"
expecteof_file "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Now commit it from candidate to running 
new "netconf commit large config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

# Now commit it again from candidate (validation takes time when
# comparing to existing)
new "netconf commit large config again"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

# Having a large db, get and put single entries many times
# Note same entries in the range alreayd there, db has same size
new "netconf add $perfreq small config"
time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    echo "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg  -y $fyang > /dev/null

new "netconf get $perfreq small config"
time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    echo "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/y[a=$rnd][b=$rnd]\" /></get-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg  -y $fyang > /dev/null

new "restconf get $perfreq small config"
time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl -sG http://localhost/restconf/data/scaling:x/y=$rnd > /dev/null
done

# Reference:
# i686 format=xml perfnr=10000/100 time: 38/29s 20190425  WITH/OUT startup copying
# i686 format=tree perfnr=10000/100 time: 72/64s 20190425 WITH/OUT startup copying
new "restconf add $perfreq small config"
time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl -s -X PUT http://localhost/restconf/data/scaling:x/y=$rnd  -d '{"scaling:y":{"a":"'$rnd'","b":"'$rnd'"}}'
done 

# Instead of many small entries, get one large in netconf and restconf
new "netconf get large config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg  -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><x xmlns="urn:example:clixon"><y><a>0</a><b>0</b></y><y><a>1</a><b>1</b></y><y><a>2</a><b>2</b></y><y><a>3</a><b>3</b></y>'

new "restconf get large config"
expecteof "/usr/bin/time -f %e curl -sG http://localhost/restconf/data" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^{"data": {"scaling:x": {"y": \[{"a": 0,"b": 0},{ "a": 1,"b": 1},{ "a": 2,"b": 2},{ "a": 3,"b": 3},'

new "restconf delete $perfreq small config"
time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    curl -s -X DELETE http://localhost/restconf/data/scaling:x/y=$rnd
done 

# Now do leaf-lists istead of leafs

new "generate large leaf-list config"
echo -n "<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><x xmlns=\"urn:example:clixon\">" > $fconfig2
for (( i=0; i<$perfnr; i++ )); do  
    echo -n "<c>$i</c>" >> $fconfig2
done
echo "</x></config></edit-config></rpc>]]>]]>" >> $fconfig2

new "netconf replace large list-leaf config"
expecteof_file "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" "$fconfig2" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf commit large leaf-list config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf add $perfreq small leaf-list config"
time -p for (( i=0; i<$perfreq; i++ )); do
    rnd=$(( ( RANDOM % $perfnr ) ))
    echo "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><c>$rnd</c></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg  -y $fyang > /dev/null

new "netconf add small leaf-list config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><c>x</c></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf commit small leaf-list config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf get large leaf-list config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg  -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><x xmlns="urn:example:clixon"><c>0</c><c>1</c>'

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
