#!/usr/bin/env bash
# Run, eg as:
# ./sum.sh # to run all tests and print 

if [ $# -gt 0 ]; then 
    echo "usage: $0 # pipe to dev/null and continue on error"
    exit -1
fi

# Pattern to run tests, default is all, but you may want to narrow it down
: ${pattern:=test_*.sh}

err=0
for testfile in $pattern; do # For lib.sh the variable must be called testfile
    echo "Running $testfile"
    ./$testfile  > /dev/null 2>&1
    errcode=$?
    if [ $errcode -ne 0 ]; then
	err=1
	echo -e "\e[31mError in $testfile errcode=$errcode"
	echo -ne "\e[0m"
    fi
done
if [ $err -eq 0 ]; then 
    echo OK
else
    echo -e "\e[31mError"
    echo -ne "\e[0m"
    exit -1
fi


