#!/bin/bash
# Run valgrind leak test for cli, restconf, netconf or background.
# Stop on first error
# 
if [ $# -ne 1 ]; then 
    echo "usage: $0 cli|netconf|restconf|backend" # valgrind memleak checks
    exit -1
fi
PROGRAM=$1

valgrindfile=$(mktemp)
echo "valgrindfile:$valgrindfile"

case "$PROGRAM" in
    'cli')
	valgrindtest=1
	RCWAIT=1
	clixon_cli="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp  --track-fds=yes --trace-children=no --child-silent-after-fork=yes --log-file=$valgrindfile clixon_cli"
;;
    'netconf')
	valgrindtest=1
	RCWAIT=1
	clixon_netconf="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp  --track-fds=yes  --trace-children=no --child-silent-after-fork=yes --log-file=$valgrindfile clixon_netconf"
;;
    'backend')
	valgrindtest=2 # This means backend valgrind test
	RCWAIT=10 # valgrind backend needs some time to get up 
	perfnr=100 # test_perf.sh restconf put more or less stops
	perfreq=10

	clixon_backend="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp --track-fds=yes --trace-children=yes --log-file=$valgrindfile clixon_backend"
;;
    'restconf')
	valgrindtest=3 # This means backend valgrind test
	sudo chmod 660 $valgrindfile
	sudo chown www-data $valgrindfile
	RCWAIT=5 # valgrind restconf needs some time to get up 
	clixon_restconf="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./valgrind-clixon.supp --track-fds=yes --trace-children=no  --child-silent-after-fork=yes --log-file=$valgrindfile /www-data/clixon_restconf"

;;
*)
    echo "usage: $0 cli|netconf|restconf|backend" # valgrind memleak checks
    rm -f $valgrindfile
    exit -1
;;
esac

err=0
testnr=0
for test in test_*.sh; do
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

