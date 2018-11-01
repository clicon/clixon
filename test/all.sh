#!/bin/bash
# Run, eg as:
# ./run.sh 2>&1 | tee test.log

# include err() and new() functions
. ./lib.sh

for test in test*.sh; do
    echo "Running $test"
    ./$test
    errcode=$?
    if [ $errcode -ne 0 ]; then
	echo "Error in $test errcode=$errcode"
	exit $errcode
    fi
done
echo OK
