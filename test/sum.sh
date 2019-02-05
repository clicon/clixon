#!/bin/bash
# Run, eg as:
# ./sum.sh # to run all tests and print 

if [ $# -gt 0 ]; then 
    echo "usage: $0 # pipe to dev/null and continue on error"
    exit -1
fi

# include err() and new() functions
. ./lib.sh
err=0
for test in test*.sh; do
    echo "Running $test"
    ./$test  > /dev/null 2>&1
    errcode=$?
    if [ $errcode -ne 0 ]; then
	err=1
	echo -e "\e[31mError in $test errcode=$errcode"
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


