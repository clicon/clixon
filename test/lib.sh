#!/bin/bash

testnr=0
testname=
clixon_cf=/usr/local/etc/routing.xml
# error and exit, arg is optional extra errmsg
err(){
  echo "Error in Test$testnr [$testname]:"
  if [ $# -gt 0 ]; then 
      echo "Expected: $1"
  fi
  if [ $# -gt 1 ]; then 
      echo "Received: $2"
  fi
  exit $testnr
}

# Increment test number and print a nice string
new(){
    testnr=`expr $testnr + 1`
    testname=$1
    >&2 echo "Test$testnr [$1]"
#    sleep 1
}

# clixon tester. First arg is command and second is expected outcome
expectfn(){
  cmd=$1
  expect=$2
  if [ $# = 3 ]; then
      expect2=$3
  else
      expect2=
  fi
  ret=`$cmd`
  if [ $? -ne 0 ]; then
    err "wrong args"
  fi
  # Match if both are empty string
  if [ -z "$ret" -a -z "$expect" ]; then
      return
  fi
  if [ -z "$ret" -a "$expect" = "^$" ]; then
      return
  fi
  # grep extended grep 
  match=`echo $ret | grep -EZo "$expect"`
#  echo "ret:\"$ret\""
#  echo "expect:\"$expect\""
#  echo "match:\"$match\""
  if [ -z "$match" ]; then
      err "$expect" "$ret"
  fi
  if [ -n "$expect2" ]; then
      match=`echo "$ret" | grep -EZo "$expect2"`
      if [ -z "$match" ]; then
	  err $expect "$ret"
      fi
  fi
}

# clixon tester. First arg is command second is stdin and
# third is expected outcome
expecteof(){
  cmd=$1
  input=$2
  expect=$3

# Do while read stuff
ret=$($cmd<<EOF 
$input
EOF
)
  # Match if both are empty string
  if [ -z "$ret" -a -z "$expect" ]; then
      return
  fi
  match=`echo "$ret" | grep -Eo "$expect"`
#  echo "ret:\"$ret\""
#  echo "expect:\"$expect\""
#  echo "match:\"$match\""
  if [ -z "$match" ]; then
      err "$expect" "$ret"
  fi
}

# clixon tester read from file for large tests
expecteof_file(){
  cmd=$1
  file=$2
  expect=$3

# Do while read stuff
ret=$($cmd<$file)
  # Match if both are empty string
  if [ -z "$ret" -a -z "$expect" ]; then
      return
  fi
  match=`echo "$ret" | grep -Eo "$expect"`
  if [ -z "$match" ]; then
      err "$expect" "$ret"
  fi
}

# clixon tester. First arg is command second is stdin and
# third is expected outcome, fourth is how long to wait
expectwait(){
  cmd=$1
  input=$2
  expect=$3
  wait=$4

# Do while read stuff
  sleep 10|cat <(echo $input) -| $cmd | while [ 1 ] ; do
    read ret
    match=$(echo "$ret" | grep -Eo "$expect");
    if [ -z "$match" ]; then
	err $expect "$ret"
    fi
    break
  done
}

