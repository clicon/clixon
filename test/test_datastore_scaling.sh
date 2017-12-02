#!/bin/bash
# Scaling test

if [ $# = 0 ]; then
    number=1000
    req=10
elif [ $# = 1 ]; then
    number=$1
    req=10
elif [ $# = 2 ]; then
    number=$1
    req=$2
else
    echo "Usage: $0 [<number> [<requests>]]"
    exit 1
fi
rnd=$(( ( RANDOM % $number ) ))

fyang=/tmp/scaling.yang
db=/tmp/text/candidate_db
name=text
dir=/tmp/text
conf="-d candidate -b $dir -p ../datastore/$name/$name.so -y /tmp -m ietf-ip"

# include err() and new() functions
. ./lib.sh
clixon_cf=/tmp/scaling-conf.xml


# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
# clixon_netconf="valgrind --tool=callgrind clixon_netconf 
clixon_netconf=clixon_netconf


cat <<EOF > $fyang
module example{
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

cat <<EOF > $clixon_cf
<config>
  <CLICON_CONFIGFILE>/tmp/test_yang.xml</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/routing/yang</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/routing/routing.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/routing/routing.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/routing</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

if [ ! -d $dir ]; then
	mkdir $dir
fi

echo "datastore_client $conf mget $req /x/y[a=$rnd][b=$rnd]"

new "generate large list config"
echo -n "<config><x>" > $db
for (( i=0; i<$number; i++ )); do  
    echo -n "<y><a>$i</a><b>$i</b></y>" >> $db
done
echo "</x></config>" >> $db

new "datastore_client $name init"
expectfn "datastore_client $conf init" ""

new "datastore $name mget"
expectfn "datastore_client $conf mget 1 /x/y[a=$rnd][b=$rnd]" "^<config><x><y><a>$rnd</a><b>$rnd</b></y></x></config>$"

new "make $req gets"
time datastore_client $conf mget $req "/x/y[a=$rnd][b=$rnd]" > /dev/null

