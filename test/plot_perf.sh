#!/bin/bash
# Transactions per second for large lists read/write plotter using gnuplot
# What do I want to plot?
# First: on i32, i64, arm32
# PART 1: Basic load
# 1. How long to write 100K entries?
#    - netconf / restconf
#    - list / leaf-list
# 2. How long to read 100K entries?
#    - netconf/ restconf
#    - list / leaf-list
# 3. How long to commit 100K entries? (netconf)
#    - list / leaf-list
#
# PART 2: Load 100K entries. Commit.
# 4. How many read operations per second?
#    - netconf/ restconf
#    - list / leaf-list
# 5. How many write operations per second?
#    - netconf / restconf
#    - list / leaf-list
# 6. How may delete operations per second?
#    - netconf / restconf
#    - list / leaf-list
# The script uses bash builtin "time" command which is somewhat difficult to
# understand. See: https://linux.die.net/man/1/bash # pipelines
# You essentially have to do: { time stuff; } 2>&1
# See: https://stackoverflow.com/questions/26784870/parsing-the-output-of-bashs-time-builtin

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# op from step to reqs
to=1000 
step=100
reqs=100

# Global variables
APPNAME=example
cfg=$dir/plot-conf.xml
fyang=$dir/plot.yang
fxml=$dir/data.xml
fjson=$dir/data.json

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
        type uint32;
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
  <CLICON_SOCK>/usr/local/var/example/example.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/example.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
</clixon-config>
EOF

# Generate file with n entries
# argument: <n> <proto>
genfile(){
    if [ $2 = netconf ]; then
	echo -n "<rpc><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><x xmlns=\"urn:example:clixon\">" > $fxml
	for (( i=0; i<$1; i++ )); do  
	    echo -n "<y><a>$i</a><b>$i</b></y>" >> $fxml
	done
	echo "</x></config></edit-config></rpc>]]>]]>" >> $fxml    
    else # restconf
	echo -n '{"scaling:x":{"y":[' > $fjson
	for (( i=0; i<$1; i++ )); do  
	    if [ $i -ne 0 ]; then
	    	echo -n ',' >> $fjson
	    fi
	    echo -n "{\"a\":$i,\"b\":\"$i\"}" >> $fjson
	done
	echo ']}}' >> $fjson
    fi
}

# Run netconffunction
# args: <op> <proto> <load> <n> <reqs>
# where proto is one of:
#   netconf, restconf
# where op is one of:
#   writeall readall commitall read write 
runnet(){
    op=$1
    n=$2 # Number of entries in DB
    reqs=$3

    echo -n "$n " >>  $dir/$op-netconf-$reqs
    case $op in
	write)
	    if [ $reqs = 0 ]; then # Write all in one go
		genfile $n netconf;
		{ time -p cat $fxml | $clixon_netconf -qf $cfg -y $fyang ; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-netconf-$reqs
	    else # reqs != 0
		{ time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $n ) ));
	echo "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>]]>]]>";
    done | $clixon_netconf -qf $cfg -y $fyang ; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-netconf-$reqs
	    fi
	    ;;
	read)
	    if [ $reqs = 0 ]; then # Read all in one go
		{ time -p  echo "<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>" | $clixon_netconf -qf $cfg -y $fyang > /dev/null ; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-netconf-$reqs
	    else # reqs != 0
		{ time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ))
	echo "<rpc><edit-config><target><candidate/></target><config><x><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg -y $fyang; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-netconf-$reqs
	    fi
	    ;;
	delete)
	    { time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ))
	echo "<rpc><edit-config><target><candidate/></target><config><x><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg -y $fyang; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-netconf-$reqs
	    ;;
	commit)
	    { time -p  echo "<rpc><commit/></rpc>]]>]]>" | $clixon_netconf -qf $cfg -y $fyang > /dev/null ; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-netconf-$reqs
	    ;;
	    *)
	err "Operation not supported" "$op"
	exit
		    ;;
    esac
}

# Run restconf function
# args: <op> <proto> <load> <n> <reqs>
# where proto is one of:
#   netconf, restconf
# where op is one of:
#   writeall readall commitall read write 
runrest(){
    op=$1
    n=$2 # Number of entries in DB
    reqs=$3
    
    echo -n "$n " >>  $dir/$op-restconf-$reqs
    case $op in
	write)
	    if [ $reqs = 0 ]; then # Write all in one go
		genfile $n restconf
		# restconf @- means from stdin
		{ time -p curl -sS -X PUT -d @$fjson http://localhost/restconf/data/scaling:x ; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-restconf-$reqs
	    else # Small requests
		{ time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $n ) ));
	curl -sS -X PUT http://localhost/restconf/data/scaling:x/y=$rnd -d "{\"scaling:y\":{\"a\":$rnd,\"b\":\"$rnd\"}}" 
    done ; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-restconf-$reqs
		# 
	    fi
	    ;;
	read)
	    if [ $reqs = 0 ]; then # Read all in one go
		{ time -p curl -sS -X GET http://localhost/restconf/data/scaling:x > /dev/null; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-restconf-$reqs
	    else # Small requests
		{ time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $n ) ));
	curl -sS -X GET http://localhost/restconf/data/scaling:x/y=$rnd  
    done ; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-restconf-$reqs
	    fi
	    ;;
	    delete)
		{ time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $n ) ));
	curl -sS -X GET http://localhost/restconf/data/scaling:x/y=$rnd  
    done ; } 2>&1 | awk '/real/ {print $2}' >> $dir/$op-restconf-$reqs
		
		;;
	    *)
	err "Operation not supported" "$op"
	exit
	;;
    esac
}


commit(){
    # commit to running
    expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"
}

reset(){
    # delete all in candidate
    expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation='delete'/></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'
    # commit to running
    commit
}

# Load n entries into candidate
# Args: <n>
load(){
    # Generate file ($fxml)
    genfile $1 netconf
    # Write it to backend in one chunk
    expecteof_file "$clixon_netconf -qf $cfg -y $fyang" "$fxml" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"
}

# Run an operation, iterate from <from> to <to> in increment of <step> 
# Each operation do <reqs> times
# args: <op> <protocol> <from> <step> <to> <reqs> <cand> <run>
# <reqs>=0 means all in one go
# <cand> <run> means a priori loaded into datastore
plot(){
    op=$1
    proto=$2
    from=$3
    step=$4
    to=$5
    reqs=$6
    can=$7
    run=$8

    if [ $# -ne 8 ]; then
	exit "plot should be called with 8 arguments, got $#"
    fi
    
    # reset file
    new "Create file $dir/$op-$proto-$reqs"
    echo "" > $dir/$op-$proto-$reqs
    for (( n=$from; n<=$to; n=$n+$step )); do  
	reset
	if [ $can = n ]; then 
	    load $n
	    if [ $run = n ]; then 
		commit
	    fi
	fi
	new "$op-$proto-$reqs $n"
	if [ $proto = netconf ]; then
	    runnet $op $n $reqs
	else
	    runrest $op $n $reqs
	fi
    done
    echo # newline
}

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

for proto in netconf restconf; do
    new "$proto write all entries to candidate (restconf:running)"
    plot write  $proto  $step $step $to 0 0 0 # all candidate 0 running 0
done

for proto in netconf restconf; do
    new "$proto read all entries from running"
    plot read   netconf  $step $step $to 0 n n # start w full datastore
done

new "Netconf commit all entries from candidate to running"
plot commit netconf $step $step $to 0 n 0 # candidate full running empty

reqs=100
for proto in netconf restconf; do
    new "$proto read $reqs from full database"
    plot read $proto $step $step $to $reqs n n 

    new "$proto Write $reqs to full database(replace / alter values)"
    plot write $proto $step $step $to $reqs n n

    new "$proto delete $reqs from full database(replace / alter values)"
    plot delete $proto $step $step $to $reqs n n
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

arch=$(arch)
gnuplot -persist <<EOF
set title "Clixon transactions per second r/w large lists" font ",14" textcolor rgbcolor "royalblue"
set xlabel "entries"
set ylabel "transactions per second"
set terminal x11  enhanced title "Clixon transactions " persist raise
plot "$dir/readlist" with linespoints title "read list", "$dir/writelist" with linespoints title "write list", "$dir/writeleaflist" with linespoints title "write leaf-list" , "$dir/restreadlist" with linespoints title "rest get list" 
EOF

#rm -rf $dir

