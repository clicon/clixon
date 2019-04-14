#!/bin/bash
# Transactions per second for large lists read/write plotter using gnuplot
# What do I want to plot?
# 1. How long to write 100K entries?
#    - netconf / restconf
#    - list / leaf-list
# 2. How long to read 100K entries?
#    - netconf/ restconf
#    - list / leaf-list
# 3. How long to commit 100K entries? (netconf)
#    - list / leaf-list
# 4. In database 100K entries. How many read operations per second?
#    - netconf/ restconf
#    - list / leaf-list
# 5. 100K entries. How many write operations per second?
#    - netconf / restconf
#    - list / leaf-list
# 6. 100K entries. How may delete operations per second?
#    - netconf / restconf
#    - list / leaf-list

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

#max=2000 # Nr of db entries
#step=200
#reqs=500

# Global variables
APPNAME=example
cfg=$dir/plot-conf.xml
fyang=$dir/plot.yang
fconfig=$dir/config

# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
# clixon_netconf="valgrind --tool=callgrind clixon_netconf 
clixon_netconf=clixon_netconf

cat <<EOF > $fyang
module scaling{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix sc;
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
</clixon-config>
EOF

# Run function
# args: <i> <reqs> <mode>
# where mode is one of:
# readlist writelist restreadlist restwritelist
runfn(){
    nr=$1 # Number of entries in DB
    reqs=$2
    operation=$3
    
#    echo "runfn nr=$nr reqs=$reqs mode=$mode"

#    new "generate config with $nr list entries"
    echo -n "<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><x  xmlns=\"urn:example:clixon\">" > $fconfig
    for (( i=0; i<$nr; i++ )); do  
	case $mode in
	    readlist|writelist|restreadlist|restwritelist)
		echo -n "<y><a>$i</a><b>$i</b></y>" >> $fconfig
		;;
	    writeleaflist)
		echo -n "<c>$i</c>" >> $fconfig
		;;
	    esac
    done

    echo "</x></config></edit-config></rpc>]]>]]>" >> $fconfig    

#    new "netconf write $nr entry to backend"
    expecteof_file "$clixon_netconf -qf $cfg -y $fyang" "$fconfig" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

    case $mode in
	readlist)
#	new "netconf GET list $reqs"
	time -p for (( i=0; i<$reqs; i++ )); do
    rnd=$(( ( RANDOM % $nr ) ))
    echo "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/y[a=$rnd][b=$rnd]\" /></get-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg -y $fyang > /dev/null
            ;;
    writelist)
#	new "netconf WRITE list $reqs"
	    time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ))
	echo "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg -y $fyang > /dev/null
    ;;
    	restreadlist)
#	new "restconf GET list $reqs"
	time -p for (( i=0; i<$reqs; i++ )); do
    rnd=$(( ( RANDOM % $nr ) ))
    curl -sSG http://localhost/restconf/data/scaling:x/y=$rnd > /dev/null
done 
            ;;
    writeleaflist)
#	new "netconf GET leaf-list $reqs"
	time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ))
	echo "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><c>$rnd</c></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg -y $fyang > /dev/null
	    ;;
    esac
#    new "discard test"
    expecteof "$clixon_netconf -qf $cfg -y $fyang" "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

}

# Step
# args: <i> <reqs> <mode>
stepfn(){
    i=$1
    reqs=$2
    mode=$3

>&2    echo "stepfn $mode: i=$i reqs=$reqs"
    echo -n "" > $fconfig
    t=$(TEST=%e runfn $i $reqs $mode 2>&1 | awk '/real/ {print $2}')
    #TEST=%e runfn $i $reqs $mode 2>&1 
    #  t is time in secs of $reqs -> transactions per second. $reqs
    p=$(echo "$reqs/$t" | bc -lq)
    # p is transactions per second. 
    # write to gnuplot file: $dir/$mode
    echo "$i $p" >> $dir/$mode
}

# Run once
#args: <step> <reqs> <max>
once(){
    # Input Parameters
    step=$1
    reqs=$2
    max=$3

    echo "oncefn step=$step reqs=$reqs max=$max"
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

    new "Intial steps as start"
    for (( i=10; i<=$step; i=i+10 )); do  
	stepfn $i $reqs readlist
	stepfn $i $reqs writelist
	stepfn $i $reqs restreadlist
	stepfn $i $reqs writeleaflist
    done
    rnd=$(( ( RANDOM % $step ) ))
    echo "curl -sSG http://localhost/restconf/data/scaling:x/y=$rnd"
    curl -sSG http://localhost/restconf/data/scaling:x/y=$rnd
exit
    new "Actual steps"
    for (( i=$step; i<=$max; i=i+$step )); do  
	stepfn $i $reqs readlist
	stepfn $i $reqs writelist
	stepfn $i $reqs restreadlist
	stepfn $i $reqs writeleaflist
    done

    new "Kill restconf daemon"
    stop_restconf

    if [ $BE -ne 0 ]; then
	new "Kill backend"
	# Check if premature kill
	pid=`pgrep -u root -f clixon_backend`
	if [ -z "$pid" ]; then
	    err "backend already dead"
	fi
	# kill backend
	stop_backend -f $cfg
    fi
}

# step=200 reqs=500 max=2000
once 200 500 1000

gnuplot -persist <<EOF
set title "Clixon transactions per second r/w large lists" font ",14" textcolor rgbcolor "royalblue"
set xlabel "entries"
set ylabel "transactions per second"
set terminal x11  enhanced title "Clixon transactions " persist raise
plot "$dir/readlist" with linespoints title "read list", "$dir/writelist" with linespoints title "write list", "$dir/writeleaflist" with linespoints title "write leaf-list" , "$dir/restreadlist" with linespoints title "rest get list" 
EOF

#rm -rf $dir

