#!/bin/bash
# Scaling test

if [ $# = 0 ]; then
    number=1000
elif [ $# = 1 ]; then
    number=$1
else
    echo "Usage: $0 [<number>]"
    exit 1
fi

fyang=/tmp/scaling.yang
fconfig=/tmp/config

# include err() and new() functions
. ./lib.sh

# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
# clixon_netconf="valgrind --tool=callgrind clixon_netconf 
clixon_netconf=clixon_netconf

cat <<EOF > $fyang
module ietf-ip{
   container x {
    list y {
      key "a";
      leaf a {
        type string;
      }
    }
    container z {
      leaf-list c {
        type string;
      }
    }
  }
}
EOF

# kill old backend (if any)
new "kill old backend"
echo "clixon_backend -zf $clixon_cf -y $fyang"
sudo clixon_backend -zf $clixon_cf -y $fyang
if [ $? -ne 0 ]; then
    err
fi

new "start backend"
# start new backend
sudo clixon_backend -If $clixon_cf -y $fyang
if [ $? -ne 0 ]; then
    err
fi

new "generate large config"
echo -n "<rpc><edit-config><target><candidate/></target><config><x>" > $fconfig
for (( i=0; i<$number; i++ )); do  
    echo -n "<y><a>$i</a></y>" >> $fconfig
done
echo "</x></config></edit-config></rpc>]]>]]>" >> $fconfig

new "netconf edit large config"
expecteof_file "time $clixon_netconf -qf $clixon_cf -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" < $fconfig

rm $fconfig

new "netconf get large config"
expecteof "time $clixon_netconf -qf $clixon_cf  -y $fyang" "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><x><y><a>0</a></y><y><a>1</a>"

new "Kill backend"
# Check if still alive
pid=`pgrep clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -zf $clixon_cf
if [ $? -ne 0 ]; then
    err "kill backend"
fi
