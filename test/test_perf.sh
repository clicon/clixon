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

new "generate large list config"
echo -n "<rpc><edit-config><target><candidate/></target><config><x>" > $fconfig
for (( i=0; i<$number; i++ )); do  
    echo -n "<y><a>$i</a><b>$i</b></y>" >> $fconfig
done
echo "</x></config></edit-config></rpc>]]>]]>" >> $fconfig

new "netconf edit large config"
expecteof_file "time -p $clixon_netconf -qf $clixon_cf -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf edit large config again"
expecteof_file "time -p $clixon_netconf -qf $clixon_cf -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

rm $fconfig

new "netconf commit large config"
expecteof "time -p $clixon_netconf -qf $clixon_cf -y $fyang" "<rpc><commit><source><candidate/></source></commit></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf add small config"
expecteof "time -p $clixon_netconf -qf $clixon_cf -y $fyang" "<rpc><edit-config><target><candidate/></target><config><x><y><a>x</a><b>y</b></y></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf commit small config"
expecteof "time -p $clixon_netconf -qf $clixon_cf -y $fyang" "<rpc><commit><source><candidate/></source></commit></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf get large config"
expecteof "time -p $clixon_netconf -qf $clixon_cf  -y $fyang" "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><x><y><a>0</a><b>0</b></y><y><a>1</a><b>1</b>"


new "generate large leaf-list config"
echo -n "<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><x>" > $fconfig
for (( i=0; i<$number; i++ )); do  
    echo -n "<c>$i</c>" >> $fconfig
done
echo "</x></config></edit-config></rpc>]]>]]>" >> $fconfig

new "netconf replace large list-leaf config"
expecteof_file "time -p $clixon_netconf -qf $clixon_cf -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

rm $fconfig

new "netconf commit large leaf-list config"
expecteof "time -p $clixon_netconf -qf $clixon_cf -y $fyang" "<rpc><commit><source><candidate/></source></commit></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf add small leaf-list config"
expecteof "time -p $clixon_netconf -qf $clixon_cf -y $fyang" "<rpc><edit-config><target><candidate/></target><config><x><c>x</c></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf commit small leaf-list config"
expecteof "time -p $clixon_netconf -qf $clixon_cf -y $fyang" "<rpc><commit><source><candidate/></source></commit></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

new "netconf get large leaf-list config"
expecteof "time -p $clixon_netconf -qf $clixon_cf  -y $fyang" "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data><x><c>0</c><c>1</c>"

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
