#!/usr/bin/env bash
# Run valgrind leak test for cli, restconf, netconf or background.
# Stop on first error
# Typical run:  ./mem.sh 2>&1 | tee mylog
    
# Pattern to run tests, default is all, but you may want to narrow it down
: ${pattern:=test_*.sh}

# Run valgrindtest once, args:
# what: (cli|netconf|restconf|backend)* # no args means all
function memonce(){
    what=$1

    valgrindfile=$(mktemp)
    echo "valgrindfile:$valgrindfile"

    clixon_cli=
    clixon_netconf=
    clixon_backend=
    clixon_restconf=
    case "$what" in
	'cli')
	    valgrindtest=1
	    : ${DEMWAIT:=5} # valgrind backend needs some time to get up 
	    clixon_cli="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp  --track-fds=yes --trace-children=no --child-silent-after-fork=yes --log-file=$valgrindfile clixon_cli"
	    ;;
	'netconf')
	    valgrindtest=1
    	    : ${DEMWAIT:=5} # valgrind backend needs some time to get up 
	    clixon_netconf="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp  --track-fds=yes  --trace-children=no --child-silent-after-fork=yes --log-file=$valgrindfile clixon_netconf"
	    ;;
	'backend')
	    valgrindtest=2 # This means backend valgrind test
	    : ${DEMWAIT:=10} # valgrind backend needs some time to get up 
	    # trace-children=no for test_restconf_rpc.sh
	    clixon_backend="/usr/bin/valgrind --num-callers=50 --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp --track-fds=yes --trace-children=no --log-file=$valgrindfile clixon_backend"
	    ;;
	'restconf')
	    valgrindtest=3 # This means restconf valgrind test
	    sudo chmod 660 $valgrindfile
	    sudo chown www-data $valgrindfile
	    : ${DEMWAIT:=15} # valgrind backend needs some time to get up 
	    clixon_restconf="/usr/bin/valgrind --num-callers=50 --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp --track-fds=yes --trace-children=no  --child-silent-after-fork=yes --log-file=$valgrindfile clixon_restconf"

	    ;;
	*)
	    echo "usage: $0 cli|netconf|restconf|backend" # valgrind memleak checks
	    rm -f $valgrindfile
	    exit -1
	    ;;
    esac


    memerr=0
    for test in $pattern; do
	if [ $testnr != 0 ]; then echo; fi
	perfnr=1000 # Limit performance tests
	testfile=$test
	. ./$test 
	errcode=$?
	endsuite
	if [ $errcode -ne 0 ]; then
	    memerr=1
	    echo -e "\e[31mError in $test errcode=$errcode"
	    echo -ne "\e[0m"
	    exit $errcode
	fi
    done
    if [ $valgrindtest -eq 1 ]; then
	checkvalgrind
	sudo rm -f $valgrindfile
    fi
}

# Print a line with ==== under
function println(){
    str=$1
    echo "$str"
    length=$(echo "$str" | wc -c)
    let i=1
    while [ $i -lt $length ]; do
	echo -n "="
	let i++
    done
    echo
}

if [ -z "$*" ]; then
    cmds="backend restconf cli netconf"
else
    cmds=$*
fi

# First run sanity
for c in $cmds; do
    if [ $c != cli -a $c != netconf -a $c != restconf -a $c != backend ]; then
	echo "c:$c"
	echo "usage: $0 [cli|netconf|restconf|backend]+" 
	echo "          with no args run all"
	exit -1
    fi
done

# Then actual run
testnr=0
memerr=0

for cmd1 in $cmds; do
    if [ $testnr != 0 ]; then echo; fi
    println "Mem test $cmd1 begin"
    memonce $cmd1
    println "Mem test $cmd1 done"
done

if [ $memerr -eq 0 ]; then 
    echo OK
else
    echo -e "\e[31mError"
    echo -ne "\e[0m"
    exit -1
fi

unset pattern
