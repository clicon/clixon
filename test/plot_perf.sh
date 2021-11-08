#!/usr/bin/env bash
# Performance of large lists. See doc/scaling/large-lists.md
# The parameters are shown below (under Default values)
# Examples
# 1. run all measurements up to 10000 entris collect all results in /tmp/plots
#    run=true plot=false to=10000 resdir=/tmp/plots ./plot_perf.sh 
# 2. Use existing data plot and show on X11
#    run=false plot=true resdir=/tmp/plots term=x11 ./plot_perf.sh
# 3. Use existing data plot i686 and armv7l data as png
#    archs="i686 armv7l" run=false plot=true resdir=/tmp/plots term=png ./plot_perf.sh 
# Need gnuplot installed

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

arch=$(arch)
# Default values
: ${to:=5000}  # Max N
: ${step=1000} # Iterate in steps (also starting point)
: ${reqs=100} # Number of requests in each burst
: ${run:=true} # run tests (or skip them). If false just plot
: ${term:=x11} # x11 interactive, alt: png
: ${resdir=$dir} # Result dir (both data and gnuplot)
: ${plot=false} # Result dir (both data and gnuplot)
: ${archs=$arch} # Plotting can be made for many architectures (not run)

# 0 prefix to protect against shell dynamic binding)
to0=$to
step0=$step
reqs0=$reqs

ext=$term # gnuplot output file extenstion

# Global variables
APPNAME=example
cfg=$dir/plot-conf.xml
fyang=$dir/plot.yang
fxml=$dir/data.xml
fjson=$dir/data.json

# Resultdir - if different from $dir that gets erased
#resdir=$dir

if [ ! -d $resdir ]; then
    mkdir $resdir
fi

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
      description "top-level container";
      list y {
         description "List with potential large number of elements";
         key "a";
         leaf a {
            description "key in list";
            type int32;
         }
         leaf b {
            description "payload data";
           type string;
         }
      }
   }
}
EOF

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir_tmp</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>scaling</CLICON_YANG_MODULE_MAIN>
  <CLICON_SOCK>/usr/local/var/example/example.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/example.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
</clixon-config>
EOF

# Generate file with n entries
# argument: <n> <proto>
function genfile(){
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
#   get put delete commit
function runnet(){
    op=$1
    nr=$2 # Number of entries in DB (keep diff from n due to shell dynamic binding)
    reqs=$3

    file=$resdir/$op-netconf-$reqs-$arch
    echo -n "$nr " >>  $file
    case $op in
	put)
	    if [ $reqs = 0 ]; then # Write all in one go
		genfile $nr netconf;
		{ time -p cat $fxml | $clixon_netconf -qf $cfg -y $fyang ; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
	    else # reqs != 0
		{ time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ));
	echo "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>]]>]]>";
    done | $clixon_netconf -qf $cfg -y $fyang > /dev/null; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
	    fi
	    ;;
	get)
	    if [ $reqs = 0 ]; then # Read all in one go
		{ time -p  echo "<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>" | $clixon_netconf -qf $cfg -y $fyang > /dev/null ; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
	    else # reqs != 0
		{ time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ))
	echo "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>]]>]]>"
		done | $clixon_netconf -qf $cfg -y $fyang > /dev/null; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
	    fi
	    ;;
	delete)
	    { time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ))
	echo "<rpc><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>]]>]]>"
done | $clixon_netconf -qf $cfg -y $fyang; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
	    ;;
	commit)
	    { time -p  echo "<rpc><commit/></rpc>]]>]]>" | $clixon_netconf -qf $cfg -y $fyang > /dev/null ; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
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
#   get put delete 
function runrest(){
    op=$1
    nr=$2 # Number of entries in DB
    reqs=$3
    
    file=$resdir/$op-restconf-$reqs-$arch
    echo -n "$nr " >>  $file
    case $op in
	put)
	    if [ $reqs = 0 ]; then # Write all in one go
		genfile $nr restconf
		# restconf @- means from stdin
		{ time -p curl $CURLOPTS -X PUT -d @$fjson http://localhost/restconf/data/scaling:x ; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
	    else # Small requests
		{ time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ));
	curl $CURLOPTS -X PUT http://localhost/restconf/data/scaling:x/y=$rnd -d "{\"scaling:y\":{\"a\":$rnd,\"b\":\"$rnd\"}}" 
    done ; } 2>&1 | awk '/real/ {print $2}' | tr , .>> $file
		# 
	    fi
	    ;;
	get)
	    if [ $reqs = 0 ]; then # Read all in one go
		{ time -p curl $CURLOPTS -X GET http://localhost/restconf/data/scaling:x > /dev/null; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
	    else # Small requests
		{ time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ));
	curl $CURLOPTS -X GET http://localhost/restconf/data/scaling:x/y=$rnd  
    done ; } 2>&1 | awk '/real/ {print $2}' | tr , .>> $file
	    fi
	    ;;
	delete)
		{ time -p for (( i=0; i<$reqs; i++ )); do
	rnd=$(( ( RANDOM % $nr ) ));
	curl $CURLOPTS -X GET http://localhost/restconf/data/scaling:x/y=$rnd  
    done ; } 2>&1 | awk '/real/ {print $2}' | tr , .>> $file
		;;
	    *)
	err "Operation not supported" "$op"
	exit
	;;
    esac
}


function commit(){
    # commit to running
    expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"
}

function reset(){
    # delete all in candidate
    expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation='delete'/></edit-config></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'
    # commit to running
    commit
}

# Load n entries into candidate
# Args: <n>
function load(){
    # Generate file ($fxml)
    genfile $1 netconf
    # Write it to backend in one chunk
    expecteof_file "$clixon_netconf -qf $cfg -y $fyang" 0 "$fxml" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"
}

# Run an operation, iterate from <from> to <to> in increment of <step> 
# Each operation do <reqs> times
# args: <op> <protocol> <from> <step> <to> <reqs> <cand> <run>
# <reqs>=0 means all in one go
# <cand> <run> means a priori loaded into datastore
function plot(){
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
    new "Create file $resdir/$op-$proto-$reqs-$arch"
    echo -n "" > $resdir/$op-$proto-$reqs-$arch
    for (( n=$from; n<=$to; n=$n+$step )); do  
	reset
	if [ $can = n ]; then 
	    load $n
	    if [ $run = n ]; then 
		commit
	    fi
	fi
	new "$op-$proto-$reqs-$arch $n"
	if [ $proto = netconf ]; then
	    runnet $op $n $reqs
	else
	    runrest $op $n $reqs
	fi
    done
    echo # newline
}

# Run an operation, iterate from <from> to <to> in increment of <step> 
# Each operation do <reqs> times
# args: <op> <protocol> <from> <step> <to> <reqs> <cand> <run>
# <reqs>=0 means all in one go
function startup(){
    from=$1
    step=$2
    to=$3
    mode=startup

    if [ $# -ne 3 ]; then
	exit "plot should be called with 3 arguments, got $#"
    fi

    # gnuplot file
    gfile=$resdir/startup-$arch    
    new "Create file $gfile"
    echo -n "" > $gfile

    # Startup db: load with n entries
    dbfile=$dir/${mode}_db
    sudo touch $dbfile
    sudo chmod 666 $dbfile
    for (( n=$from; n<=$to; n=$n+$step )); do  
	new "startup-$arch $n"
	new "Generate $n entries to $dbfile"
	echo -n "<config><x xmlns=\"urn:example:clixon\">" > $dbfile
	for (( i=0; i<$n; i++ )); do  
	    echo -n "<y><a>$i</a><b>$i</b></y>" >> $dbfile
	done
	echo "</x></config>" >> $dbfile

	new "Startup backend once -s $mode -f $cfg -y $fyang"
	echo -n "$n " >>  $gfile
	{ time -p sudo $clixon_backend -F1 -D $DBG -s $mode -f $cfg -y $fyang 2> /dev/null; } 2>&1 |  awk '/real/ {print $2}' | tr , . >> $gfile

    done
    echo # newline
}

if $run; then

    # Startup test before regular backend/restconf start since we only start
    # backend a single time
    startup $step $step $to

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
    sleep $DEMWAIT

    to=$to0
    step=$step0
    reqs=$reqs0


    # Put all tests
    for proto in netconf restconf; do
	new "$proto put all entries to candidate (restconf:running)"
	plot put  $proto  $step $step $to 0 0 0 # all candidate 0 running 0
    done

    # Get all tests
    for proto in netconf restconf; do
	new "$proto get all entries from running"
	plot get $proto  $step $step $to 0 n n # start w full datastore
    done

    # Netconf commit all
    new "Netconf commit all entries from candidate to running"
    plot commit netconf $step $step $to 0 n 0 # candidate full running empty

    # Transactions get/put/delete
    reqs=$reqs0
    for proto in netconf restconf; do
	new "$proto get $reqs from full database"
	plot get $proto $step $step $to $reqs n n 

	new "$proto put $reqs to full database(replace / alter values)"
	plot put $proto $step $step $to $reqs n n

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
fi # if run

if $plot; then

# 0. Startup
gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/startup-$a\" title \"startup-$a\","
done

gnuplot -persist <<EOF
set title "Clixon startup"
set style data linespoint
set xlabel "Entries"
set ylabel "Time[s]"
set grid
set terminal $term
set yrange [*:*]
set output "$resdir/clixon-startup.$term"
plot $gplot
EOF

# 1. Get config
gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/get-restconf-0-$a\" title \"rc-$a\", \"$resdir/get-netconf-0-$a\" title \"nc-$a\","
done

gnuplot -persist <<EOF
set title "Clixon get config"
set style data linespoint
set xlabel "Entries"
set ylabel "Time[s]"
set grid
set terminal $term
set yrange [*:*]
set output "$resdir/clixon-get-0.$term"
plot $gplot
EOF


# 2. Put config

gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/put-restconf-0-$a\" title \"rc-$a\", \"$resdir/put-netconf-0-$a\" title \"nc-$a\","
done

gnuplot -persist <<EOF
set title "Clixon put config"
set style data linespoint
set xlabel "Entries"
set ylabel "Time[s]"
set grid
set terminal $term
set yrange [*:*]
set output "$resdir/clixon-put-0.$term"
plot $gplot
EOF

# 3. Commit config

gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/commit-netconf-0-$a\" title \"nc-$a\","
done

gnuplot -persist <<EOF
set title "Clixon commit config"
set style data linespoint
set xlabel "Entries"
set ylabel "Time[s]"
set grid
set terminal $term
set yrange [*:*]
set output "$resdir/clixon-commit-0.$term"
plot $gplot
EOF

# 4. Get single entry 

gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/get-restconf-100-$a\" using 1:(\$2/$reqs0) title \"rc-$a\", \"$resdir/get-netconf-100-$a\" using 1:(\$2/$reqs0) title \"nc-$a\","
done

gnuplot -persist <<EOF
set title "Clixon get single entry"
set style data linespoint
set xlabel "Entries"
set ylabel "Time[s]"
set grid
set terminal $term
set yrange [*:*]
set output "$resdir/clixon-get-100.$term"
plot $gplot
EOF

# 5. Put single entry 

gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/put-restconf-100-$a\" using 1:(\$2/$reqs0) title \"rc-$a\", \"$resdir/put-netconf-100-$a\" using 1:(\$2/$reqs0) title \"nc-$a\","
done

gnuplot -persist <<EOF
set title "Clixon put single entry"
set style data linespoint
set xlabel "Entries"
set ylabel "Time[s]"
set grid
set terminal $term
set yrange [*:*]
set output "$resdir/clixon-put-100.$term"
plot $gplot
EOF

# 6. Delete single entry 

gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/delete-restconf-100-$a\" using 1:(\$2/$reqs0) title \"rc-$a\", \"$resdir/delete-netconf-100-$a\" using 1:(\$2/$reqs0) title \"nc-$a\","

done

gnuplot -persist <<EOF
set title "Clixon delete single entry"
set style data linespoint
set xlabel "Entries"
set ylabel "Time[s]"
set grid
set terminal $term
set yrange [*:*]
set output "$resdir/clixon-delete-100.$term"
plot $gplot
EOF

fi # if plot

#rm -rf $dir

