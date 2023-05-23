#!/usr/bin/env bash
# Performance of large lists. See doc/scaling/large-lists.md
# The parameters are shown below (under Default values)
# Examples
# 1. run all measurements up to 10000 entries collect all results in /tmp/plots
#    run=true plot=false to=10000 resdir=/tmp/plots ./plot_perf.sh 
# 2. Use existing data plot and show on X11
#    run=false plot=true resdir=/tmp/plots term=x11 ./plot_perf.sh
# 3. Use existing data plot i686 and armv7l data as png
#    archs="i686 armv7l" run=false plot=true resdir=/tmp/plots term=png ./plot_perf.sh 
# Need gnuplot installed

set -u

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
: ${protos="netconf restconf"}
: ${state=true} # Generate state data and netconf get state plot

# 0 prefix to protect against shell dynamic binding)
to0=$to
step0=$step
reqs0=$reqs

ext=$term # gnuplot output file extension

# Global variables
APPNAME=example
cfg=$dir/plot-conf.xml
fyang=$dir/scaling.yang
fstate=$dir/state.xml
fxml=$dir/data.xml
fjson=$dir/data.json

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
         leaf status {
            description "state data";
            type string;
            config false;
         }
      }
   }
}
EOF

RESTCONFIG=$(restconf_config none false)
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/example/example.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/example/example.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_VALIDATE_STATE_XML>false</CLICON_VALIDATE_STATE_XML>
  $RESTCONFIG
</clixon-config>
EOF

# Generate file $fxml or $fjson with "nr" entries for PUT operations
# arguments:
# 1: <nr>
# 2: <proto>  netconf(in xml) or json (for restconf)
function genfile()
{
    new "genfile"
    nr=$1
    myproto=$2

    if [ $myproto = netconf ]; then
        rpc="<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><x xmlns=\"urn:example:clixon\">"
        for (( i=0; i<$nr; i++ )); do  
            rpc+="<y><a>$i</a><b>$i</b></y>"
        done
        rpc+="</x></config></edit-config></rpc>"
        echo -n "$DEFAULTHELLO" > $fxml
        echo "$(chunked_framing "$rpc")" >> $fxml
    else # json
        echo -n '{"scaling:x":{"y":[' > $fjson
        for (( i=0; i<$nr; i++ )); do  
            if [ $i -ne 0 ]; then
                echo -n ',' >> $fjson
            fi
            echo -n "{\"a\":$i,\"b\":\"$i\"}" >> $fjson
        done
        echo ']}}' >> $fjson
    fi
}

# Generate state file with "nr" entries
# arguments:
# 1: <nr>     Number of entries
# 2: <fstate> File name
function genstate()
{
    nr=$1
    fstate=$2
    echo "<x xmlns=\"urn:example:clixon\">" > $fstate
    for (( i=0; i<$nr; i++ )); do
        echo "<y><a>$i</a><state>$i</state></y>" >> $fstate
    done
    echo "</x>" >> $fstate
}

# Run netconf function
# args:
# 1: <op>    put, get, commit, delete
# 2: <nr>    Number of entries
# 3: <reqs> =0 means all in one go
# 4: <st>  true: Also generate/get state data
function runnetconf()
{
    op=$1
    nr=$2 # Number of entries in DB (keep diff from n due to shell dynamic binding)
    reqs=$3
    st=$4

    file=$resdir/$op-netconf-$reqs-$st-$arch
    new "runnetconf $file $nr"
    echo -n "$nr " >>  $file
    case $op in
        put)
            if [ $reqs = 0 ]; then # Write all in one go
                genfile $nr netconf;
                { time -p cat $fxml | $clixon_netconf -qf $cfg; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
            else # reqs != 0
                { time -p for (( i=0; i<$reqs; i++ )); do
                    rnd=$(( ( RANDOM % $nr ) ));
                    rpc=$(chunked_framing "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>")
                    if [ $i == 0 ]; then
                        echo -n "$DEFAULTHELLO";
                    fi       
                    echo "$rpc"
                done | $clixon_netconf -qf $cfg > /dev/null; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
            fi
            ;;
        get)
            if $st; then
                GET1="<get>"
                GET2="</get>"
            else
                GET1="<get-config><source><running/></source>"
                GET2="</get-config>"
            fi
            if [ $reqs = 0 ]; then # Read all in one go
                rpc=$(chunked_framing "<rpc $DEFAULTNS>${GET1}${GET2}</rpc>")
                { time -p  echo "$DEFAULTHELLO$rpc" | $clixon_netconf -qf $cfg > /dev/null ; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
            else # reqs != 0
                { time -p for (( i=0; i<$reqs; i++ )); do
                    rnd=$(( ( RANDOM % $nr ) ))
                    rpc=$(chunked_framing "<rpc $DEFAULTNS>${GET1}<filter type=\"xpath\" select=\"/ex:x/ex:y[ex:a=$rnd]\" xmlns:ex=\"urn:example:clixon\"/>${GET2}</rpc>")
                    if [ $i == 0 ]; then
                        echo -n "$DEFAULTHELLO";
                    fi       
                    echo "$rpc"
                done | $clixon_netconf -qf $cfg > /dev/null; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
                echo $file
            fi
            ;;
        delete)
            if [ $reqs = 0 ]; then # Delete all in one go
                rpc=$(chunked_framing "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>")
                { time -p  echo "$DEFAULTHELLO$rpc" | $clixon_netconf -qf $cfg > /dev/null ; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file    
            else
            { time -p for (( i=0; i<$reqs; i++ )); do
                rnd=$(( ( RANDOM % $nr ) ))
                rpc=$(chunked_framing "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>$rnd</a><b>$rnd</b></y></x></config></edit-config></rpc>")
                if [ $i == 0 ]; then
                    echo -n "$DEFAULTHELLO";
                fi       
                echo "$rpc"
            done | $clixon_netconf -qf $cfg; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
            fi
            ;;
        commit)
            rpc=$(chunked_framing "<rpc $DEFAULTNS><commit/></rpc>")
            { time -p  echo "$DEFAULTHELLO$rpc" | $clixon_netconf -qf $cfg > /dev/null ; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
            ;;
            *)
        err "Operation not supported" "$op"
        exit
        ;;
    esac
}

# Run restconf function
# args: 
# 1: <op>    put, get, commit, delete
# 2: <nr>    Number of entries
# 3: <reqs> =0 means all in one go
# 4: <st>    true: Also generate/get state data
function runrestconf()
{
    op=$1
    nr=$2 # Number of entries in DB
    reqs=$3
    st=$4
    
    file=$resdir/$op-restconf-$reqs-$st-$arch
    new "runrestconf $file $nr"
    echo -n "$nr " >>  $file
    case $op in
        put)
            if [ $reqs = 0 ]; then # Write all in one go
                genfile $nr json
                # restconf @- means from stdin
                { time -p curl $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' -d @$fjson $RCPROTO://localhost/restconf/data/scaling:x ; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
            else # Small requests
                { time -p for (( i=0; i<$reqs; i++ )); do
                    rnd=$(( ( RANDOM % $nr ) ));
                    curl $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/scaling:x/y=$rnd -d "{\"scaling:y\":{\"a\":$rnd,\"b\":\"$rnd\"}}" 
                done ; } 2>&1 | awk '/real/ {print $2}' | tr , .>> $file
                # 
            fi
            ;;
        get)
            if $st; then
                CONTENT=all
            else
                CONTENT=config
            fi
            if [ $reqs = 0 ]; then # Read all in one go
                { time -p curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/scaling:x?content=$CONTENT > /dev/null; } 2>&1 | awk '/real/ {print $2}' | tr , . >> $file
            else # Small requests
                { time -p for (( i=0; i<$reqs; i++ )); do
                    rnd=$(( ( RANDOM % $nr ) ));
                    curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/scaling:x/y=$rnd?content=$CONTENT  
                done ; } 2>&1 | awk '/real/ {print $2}' | tr , .>> $file
            fi
            ;;
        delete)
                { time -p for (( i=0; i<$reqs; i++ )); do
        rnd=$(( ( RANDOM % $nr ) ));
        curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/scaling:x/y=$rnd  
    done ; } 2>&1 | awk '/real/ {print $2}' | tr , .>> $file
                ;;
            *)
        err "Operation not supported" "$op"
        exit
        ;;
    esac
}

function commit()
{
    # commit to running
    new "commit"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
}

# Delete all in candidate and commit, and state file
function reset()
{
    new "reset"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation='delete'/></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
    # commit to running
    commit
    echo "" > $fstate
}

# Load nr entries into candidate
# Args: <nr>
function load()
{
    new "load $1"
    nr=$1
    # Generate file ($fxml)
    genfile $nr netconf
    # Write it to backend in one chunk
    new "generated netconf"
    expecteof_file "$clixon_netconf -qef $cfg" 0 "$fxml" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>$"
    new "load done"
}

# Run an operation, iterate from <from> to <to> in increment of <step> 
# Each operation do <reqs> times
# args:
# 1: <op>    put, get, commit, delete
# 2: <proto> netconf or restconf
# 3: <from>  Iterate from
# 4: <step>  in steps
# 5: <to>    Increment to
# 6: <reqs>  =0 means all in one go
# 7: <fill>  Three values: "no", "candidate": prefill candidare, "running": also commit into running
# 8: <st>    false: no state, true: Also get state data
function genplot()
{
    op=$1
    proto=$2
    from=$3
    step=$4
    to=$5
    reqs=$6
    fill=$7
    st=$8

    new "genplot $proto"
    if [ $# -ne 8 ]; then
        exit "plot should be called with 8 arguments, got $#"
    fi
    # reset file
    new "Create file $resdir/$op-$proto-$reqs-$st-$arch"
    echo -n "" > $resdir/$op-$proto-$reqs-$st-$arch
    for (( nr=$from; nr<=$to; nr=$nr+$step )); do  
        reset
        if $st; then
            genstate $nr $fstate
        fi
        if [ $fill = candidate ]; then 
            load $nr
        elif [ $fill = running ]; then 
            load $nr
            commit
        fi
        if [ $proto = netconf ]; then
            runnetconf $op $nr $reqs $st
        else
            runrestconf $op $nr $reqs $st
        fi
    done
    echo # newline
}

# Run an operation, iterate from <from> to <to> in increment of <step> 
# Each operation do <reqs> times
# args: <op> <protocol> <from> <step> <to> <reqs> <cand> <run>
# <reqs>=0 means all in one go
function startup()
{
    from=$1
    step=$2
    to=$3
    mode=startup

    new "startup"
    if [ $# -ne 3 ]; then
        exit "startup should be called with 3 arguments, got $#"
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

        new "Startup backend once -s $mode -f $cfg"
        echo -n "$n " >>  $gfile
        { time -p sudo $clixon_backend -F1 -D $DBG -s $mode -f $cfg 2> /dev/null; } 2>&1 |  awk '/real/ {print $2}' | tr , . >> $gfile
    done
    echo # newline
}

if $run; then

    # Startup test before regular backend/restconf start since we only start
    # backend a single time
    startup $step $step $to

    new "test params: -f $cfg"
    if [ $BE -ne 0 ]; then
        new "kill old backend"
        sudo clixon_backend -zf $cfg
        if [ $? -ne 0 ]; then
            err
        fi
        new "start backend -s init -f $cfg -- -sS $fstate"
        start_backend -s init -f $cfg -- -sS $fstate

        new "wait backend"
        wait_backend
    fi
    if [ $RC -ne 0 ]; then
        new "kill old restconf daemon"
        stop_restconf_pre

        new "start restconf daemon"
        start_restconf -f $cfg

        new "wait restconf"
        wait_restconf
    fi

    to=$to0
    step=$step0
    reqs=$reqs0

    # Put all tests
    for pr in ${protos}; do
        new "$pr put all entries to candidate (restconf:running)"
        genplot put  $pr  $step $step $to 0 no false # all candidate 0 running 0
    done

    # Netconf commit all
    new "Netconf commit all entries from candidate to running"
    genplot commit netconf $step $step $to 0 candidate false # candidate full running empty

    # Get all tests
    for pr in ${protos}; do
        new "$pr get all config entries from running"
        genplot get $pr $step $step $to 0 running false # start w full datastore
    done
    if $state; then
        for pr in ${protos}; do
            new "$pr get all state entries from running"
            genplot get $pr $step $step $to 0 running true # start w full datastore
        done
    fi
    
    # Transactions get/put/delete
    reqs=$reqs0
    for pr in ${protos} ; do
        new "$pr get $reqs from full database"
        genplot get $pr $step $step $to $reqs running false
        
        new "$pr put $reqs to full database(replace / alter values)"
        genplot put $pr $step $step $to $reqs running false

        new "$pr delete $reqs from full database(replace / alter values)"
        genplot delete $pr $step $step $to $reqs running false
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
    gplot="$gplot \"$resdir/get-restconf-0-false-$a\" title \"rc-$a\", \"$resdir/get-netconf-0-false-$a\" title \"nc-$a\","
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

# 2. Get state
if $state; then
gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/get-restconf-0-true-$a\" title \"rc-$a\", \"$resdir/get-netconf-0-true-$a\" title \"nc-$a\","
done

gnuplot -persist <<EOF
set title "Clixon get state"
set style data linespoint
set xlabel "Entries"
set ylabel "Time[s]"
set grid
set terminal $term
set yrange [*:*]
set output "$resdir/clixon-getstate-0.$term"
plot $gplot
EOF
fi
# 3. Put config

gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/put-restconf-0-false-$a\" title \"rc-$a\", \"$resdir/put-netconf-0-false-$a\" title \"nc-$a\","
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

# 4. Commit config

gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/commit-netconf-0-false-$a\" title \"nc-$a\","
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

# 5. Get single entry 

gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/get-restconf-100-false-$a\" using 1:(\$2/$reqs0) title \"rc-$a\", \"$resdir/get-netconf-100-false-$a\" using 1:(\$2/$reqs0) title \"nc-$a\","
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

# 6. Put single entry 

gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/put-restconf-100-false-$a\" using 1:(\$2/$reqs0) title \"rc-$a\", \"$resdir/put-netconf-100-false-$a\" using 1:(\$2/$reqs0) title \"nc-$a\","
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

# 7. Delete single entry 

gplot=""
for a in $archs; do
    gplot="$gplot \"$resdir/delete-restconf-100-false-$a\" using 1:(\$2/$reqs0) title \"rc-$a\", \"$resdir/delete-netconf-100-false-$a\" using 1:(\$2/$reqs0) title \"nc-$a\","

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

unset to
unset step
unset reqs
unset run
unset term
unset resdir
unset plot
unset archs
unset proto
unset protos
#rm -rf $dir

