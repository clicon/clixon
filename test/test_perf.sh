#!/bin/bash
# Scaling test

number=5000
req=100
if [ $# = 0 ]; then
    number=1000
elif [ $# = 1 ]; then
    number=$1
elif [ $# = 2 ]; then
    number=$1
    req=$2
else
    echo "Usage: $0 [<number> [<requests>]]"
    exit 1 # Scaling
fi
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/scaling-conf.xml
fyang=$dir/scaling.yang
fconfig=$dir/config

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
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>scaling</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

new "test params: -f $cfg" -y $fyang
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend  -s init -f $cfg -y $fyang"
    # start new backend
    sudo $clixon_backend -s init -f $cfg -y $fyang -D $DBG
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon"
sudo su -c "$clixon_restconf -f $cfg -y $fyang -D $DBG" -s /bin/sh www-data &

sleep $RCWAIT

new "generate 'large' config with $number list entries"
echo -n "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\">" > $fconfig
for (( i=0; i<$number; i++ )); do  
    echo -n "<y><a>$i</a><b>$i</b></y>" >> $fconfig
done
echo "</x></config></edit-config></rpc>]]>]]>" >> $fconfig

# Just for manual dbg
echo "$clixon_netconf -qf $cfg  -y $fyang"

new "netconf write large config"
expecteof_file "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#echo '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' | $clixon_netconf -qf $cfg  -y $fyang 

new "netconf write large config again"
expecteof_file "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#echo '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' | $clixon_netconf -qf $cfg  -y $fyang 

rm $fconfig

new "netconf commit large config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf commit large config again"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf add small (1 entry) config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><y><a>x</a><b>y</b></y></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf get $req small config"
time -p for (( i=0; i<$req; i++ )); do
    rnd=$(( ( RANDOM % $number ) ))
    echo "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/y[a=$rnd][b=$rnd]\" /></get-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg  -y $fyang > /dev/null

new "netconf get $req restconf small config"
time -p for (( i=0; i<$req; i++ )); do
    rnd=$(( ( RANDOM % $number ) ))
#XXX    curl -sX PUT -d {"y":{"a":"$rnd","b":"$rnd"}} http://localhost/restconf/data/x/y=$rnd,$rnd 
done 

new "netconf add $req small config"
time -p for (( i=0; i<$req; i++ )); do
    rnd=$(( ( RANDOM % $number ) ))
    echo "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg  -y $fyang > /dev/null

new "netconf add $req restconf small config"
time -p for (( i=0; i<$req; i++ )); do
    rnd=$(( ( RANDOM % $number ) ))
    curl -sG http://localhost/restconf/data/x/y=$rnd,$rnd > /dev/null
done 

new "netconf get large config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg  -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><x xmlns="urn:example:clixon"><y><a>0</a><b>0</b></y><y><a>1</a><b>1</b>'

new "generate large leaf-list config"
echo -n "<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><x xmlns=\"urn:example:clixon\">" > $fconfig
for (( i=0; i<$number; i++ )); do  
    echo -n "<c>$i</c>" >> $fconfig
done
echo "</x></config></edit-config></rpc>]]>]]>" >> $fconfig

new "netconf replace large list-leaf config"
expecteof_file "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

rm $fconfig

new "netconf commit large leaf-list config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf add $req small leaf-list config"
time -p for (( i=0; i<$req; i++ )); do
    rnd=$(( ( RANDOM % $number ) ))
    echo "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><c>$rnd</c></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg  -y $fyang > /dev/null

new "netconf add small leaf-list config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><c>x</c></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf commit small leaf-list config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf get large leaf-list config"
expecteof "/usr/bin/time -f %e $clixon_netconf -qf $cfg  -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><x xmlns="urn:example:clixon"><c>0</c><c>1</c>'

new "Kill restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

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
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
