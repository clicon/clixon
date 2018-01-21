#!/bin/bash
# Transactions per second for large lists read/write plotter using gnuplot
#
. ./lib.sh
max=200 # Nr of db entries
step=100
reqs=1000
cfg=$dir/scaling-conf.xml
fyang=$dir/scaling.yang
fconfig=$dir/config

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

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$fyang</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>ietf-ip</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/routing/routing.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/routing/routing.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/routing</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

run(){
    nr=$1 # Number of entries in DB
    reqs=$2
    mode=$3
    
    echo -n "<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><x>" > $fconfig
    for (( i=0; i<$nr; i++ )); do  
	echo -n "<c>$i</c>" >> $fconfig
	echo -n "<y><a>$i</a><b>$i</b></y>" >> $fconfig
    done
    echo "</x></config></edit-config></rpc>]]>]]>" >> $fconfig    

    expecteof_file "$clixon_netconf -qf $cfg -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

    case $mode in
	readlist)
	time -p for (( i=0; i<$reqs; i++ )); do
    rnd=$(( ( RANDOM % $nr ) ))
    echo "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/y[a=$rnd][b=$rnd]\" /></get-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg  -y $fyang > /dev/null
            ;;
	writelist)
	    time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ))
	echo "<rpc><edit-config><target><candidate/></target><config><x><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg  -y $fyang > /dev/null
            ;;
	readleaflist)
	time -p for (( i=0; i<$reqs; i++ )); do
    rnd=$(( ( RANDOM % $nr ) ))
    echo "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x[c=$rnd]\" /></get-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg  -y $fyang > /dev/null
	    ;;
    writeleaflist)
	time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ))
	echo "<rpc><edit-config><target><candidate/></target><config><x><c>$rnd</c></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg  -y $fyang > /dev/null
	    ;;
    esac
    expecteof "$clixon_netconf -qf $cfg" "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"
}

step(){
    i=$1
    mode=$2
    echo -n "" > $fconfig
    t=$(TEST=%e run $i $reqs $mode $ 2>&1 | awk '/real/ {print $2}')
    # t is time in secs of $reqs -> transactions per second. $reqs
    p=$(echo "$reqs/$t" | bc -lq)
    # p is transactions per second. 
    echo "$i $p" >> $dir/$mode
}

once()(
    # kill old backend (if any)
    sudo clixon_backend -zf $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi

    # start new backend
    sudo clixon_backend -s init -f $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi

    # Always as a start
    for (( i=10; i<=$step; i=i+10 )); do  
	step $i readlist
	step $i writelist
	step $i readleaflist
	step $i writeleaflist
    done
    # Actual steps
    for (( i=$step; i<=$max; i=i+$step )); do  
	step $i readlist
	step $i readleaflist
	step $i writelist
	step $i writeleaflist
    done

    # Check if still alive
    pid=`pgrep clixon_backend`
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err "kill backend"
    fi

)

once

gnuplot -persist <<EOF
set title "Clixon transactions per second r/w large lists" font ",14" textcolor rgbcolor "royalblue"
set xlabel "entries"
set ylabel "transactions per second"
set terminal wxt  enhanced title "CLixon transactions " persist raise
plot "$dir/readlist" with linespoints title "read list", "$dir/writelist" with linespoints title "write list", "$dir/readleaflist" with linespoints title "read leaf-list", "$dir/writeleaflist" with linespoints title "write leaf-list" 
EOF

rm -rf $dir


