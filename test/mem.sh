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
	DEMSLEEP=1
	clixon_cli="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./clixon.supp --trace-children=no --child-silent-after-fork=yes --log-file=$valgrindfile clixon_cli"
;;
    'netconf')
	valgrindtest=1
	DEMSLEEP=1
	clixon_netconf="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./clixon.supp --trace-children=no --child-silent-after-fork=yes --log-file=$valgrindfile clixon_netconf"
;;
#    'backend')
#	valgrindtest=2
#	DEMSLEEP=20
#	clixon_backend="/usr/bin/valgrind --leak-check=full --show-leak-kinds=all --suppressions=./clixon.supp --trace-children=yes --log-file=$valgrindfile clixon_backend"
#;;
*)
    echo "usage: $0 cli|netconf|restconf|backend" # valgrind memleak checks
    exit -1
;;
esac

rm -f 

err=0
testnr=0
for test in test*.sh; do
    testfile=$test
    DEMSLEEP=$DEMSLEEP . ./$test 
    errcode=$?
    if [ $errcode -ne 0 ]; then
	err=1
	echo -e "\e[31mError in $test errcode=$errcode"
	echo -ne "\e[0m"
	exit $errcode
    fi
    if [ $valgrindtest -eq 2 ]; then
#	sudo cat $valgrindfile
	sudo checkvalgrind
#	sudo rm -f $valgrindfile
    fi
done
checkvalgrind
rm -f $valgrindfile

