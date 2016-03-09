#!/bin/sh

testnr=0
testnname=
clixon_cf=/usr/local/etc/routing.conf
# error and exit, arg is optional extra errmsg
err(){
  echo "Error in Test$testnr [$testname] $1"
  exit $testnr
}

# Increment test number and print a nice string
new(){
    testnr=`expr $testnr + 1`
    testname=$1
    echo "Test$testnr [$1]"
#    sleep 1
}

# clicon_cli tester. First arg is command and second is expected outcome
expectfn(){

  cmd=$1
  expect=$2
  ret=`$cmd`
  if [ $? -ne 0 ]; then
    err
  fi
  # Match if both are empty string
  if [ -z "$ret" -a -z "$expect" ]; then
      return
  fi
  match=`echo "$ret" | grep -Eo "$expect"`
#  echo "ret:$ret"
#  echo "expect:$expect"
#  echo "match:$match"
  if [ -z "$match" ]; then
      err "\nExpected:\t\"$expect\"\nGot:\t\"$ret\""
  fi
}

