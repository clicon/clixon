#!/bin/bash
# Run valgrind leak test for cli, restconf, netconf or background.
# Stop on first error

    
# Run valgrindtest once, args:
# what: cli|netconf|restconf|backend
memonce(){
    what=$1

    valgrindfile=$(mktemp)
    echo "valgrindfile:$valgrindfile"

    case "$what" in
	'cli')
	    valgrindtest=1
	    : ${RCWAIT:=5} # valgrind backend needs some time to get up 
	    clixon_cli="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp  --track-fds=yes --trace-children=no --child-silent-after-fork=yes --log-file=$valgrindfile clixon_cli"
	    ;;
	'netconf')
	    valgrindtest=1
    	    : ${RCWAIT:=5} # valgrind backend needs some time to get up 
	    clixon_netconf="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp  --track-fds=yes  --trace-children=no --child-silent-after-fork=yes --log-file=$valgrindfile clixon_netconf"
	    ;;
	'backend')
	    valgrindtest=2 # This means backend valgrind test
	    : ${RCWAIT:=5} # valgrind backend needs some time to get up 
	    perfnr=100 # test_perf.sh restconf put more or less stops
	    perfreq=10

	    clixon_backend="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp --track-fds=yes --trace-children=yes --log-file=$valgrindfile clixon_backend"
	    ;;
	'restconf')
	    valgrindtest=3 # This means backend valgrind test
	    sudo chmod 660 $valgrindfile
	    sudo chown www-data $valgrindfile
	    : ${RCWAIT:=5} # valgrind backend needs some time to get up 
	    clixon_restconf="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp --track-fds=yes --trace-children=no  --child-silent-after-fork=yes --log-file=$valgrindfile /www-data/clixon_restconf"

	    ;;
	*)
	    echo "usage: $0 cli|netconf|restconf|backend" # valgrind memleak checks
	    rm -f $valgrindfile
	    exit -1
	    ;;
    esac

    err=0
    for test in test_*.sh; do
	if [ $testnr != 0 ]; then echo; fi
	testfile=$test
	. ./$test 
	errcode=$?
	if [ $errcode -ne 0 ]; then
	    err=1
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
for c in $cmds; do
    if [ $testnr != 0 ]; then echo; fi
    echo "Mem test for $c"
    echo "================="
    memonce $c
done
