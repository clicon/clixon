#!/bin/bash
# Run, eg as:
# ./all.sh 2>&1 | tee test.log # break on first test
# ./all.sh summary # to run all tests and print 

summary=0
if [ $# -gt 0 ]; then 
    summary=1
fi
if [ $# -gt 1 ]; then 
    echo "usage: $0 [summary] # pipe to dev/null and continue on error"
    exit -1
fi

# include err() and new() functions
. ./lib.sh
err=0
for test in test*.sh; do
    echo "Running $test"
    if [ $summary -ne 0 ]; then
	./$test  > /dev/null 2>&1
	errcode=$?
    else
	./$test 
	errcode=$?
    fi
    if [ $errcode -ne 0 ]; then
	err=1
	echo -e "\e[31mError in $test errcode=$errcode"
	echo -ne "\e[0m"
	if [ $summary -eq 0 ]; then
	    exit $errcode
	fi
    fi
done
if [ $err -eq 0 ]; then 
    echo OK
else
    echo -e "\e[31mError"
    echo -ne "\e[0m"
fi


