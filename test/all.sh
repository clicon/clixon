#!/usr/bin/env bash
# Run, eg as:
# ./all.sh 2>&1 | tee test.log # break on first test

# Pattern to run tests, default is all, but you may want to narrow it down
: ${pattern:=test_*.sh}

if [ $# -gt 0 ]; then 
    echo "usage: $0 # detailed logs and stop on first error. Use pattern=\"\" $0 to"
    echo "     Use pattern=<pattern> $0 to narrow down test cases"
    exit -1
fi

err=0
testnr=0
for test in $pattern; do
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
if [ $err -eq 0 ]; then 
    echo OK
else
    echo -e "\e[31mError"
    echo -ne "\e[0m"
    exit -1
fi


