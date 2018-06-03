#!/bin/bash
# Define test functions.
# Create working dir as variable "dir"

testnr=0
testname=

# For memcheck
#clixon_cli="valgrind --leak-check=full --show-leak-kinds=all clixon_cli"
clixon_cli=clixon_cli

# For memcheck / performance
#clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
#clixon_netconf="valgrind --tool=callgrind clixon_netconf"
clixon_netconf=clixon_netconf

# How to run restconf stand-alone and using valgrind
#sudo su -c "/www-data/clixon_restconf -f $cfg -D" -s /bin/sh www-data
#sudo su -c "valgrind --leak-check=full --show-leak-kinds=all /www-data/clixon_restconf -f $cfg -D" -s /bin/sh www-data

#clixon_backend="valgrind --leak-check=full --show-leak-kinds=all clixon_backend"
clixon_backend=clixon_backend

dir=/var/tmp/$0
if [ ! -d $dir ]; then
    mkdir $dir
fi
rm -rf $dir/*

# error and exit, arg is optional extra errmsg
err(){
  echo -e "\e[31m\nError in Test$testnr [$testname]:"
  if [ $# -gt 0 ]; then 
      echo "Expected: $1"
  fi
  if [ $# -gt 1 ]; then 
      echo "Received: $2"
  fi
  echo -e "\e[0m:"
  echo "$ret"| od -t c > $dir/clixon-ret
  echo "$expect"| od -t c > $dir/clixon-expect
  diff $dir/clixon-ret $dir/clixon-expect
  exit $testnr
}

# Increment test number and print a nice string
new(){
    testnr=`expr $testnr + 1`
    testname=$1
    >&2 echo "Test$testnr [$1]"
}
new2(){
    testnr=`expr $testnr + 1`
    testname=$1
    >&2 echo -n "Test$testnr [$1]"
}

# clixon command tester.
# Arguments:
# - command,
# - expected command return value (0 if OK)
# - expected stdout outcome,
# - expected2 stdout outcome,
expectfn(){
  cmd=$1
  retval=$2
  expect="$3"

  if [ $# = 4 ]; then
      expect2=$4
  else
      expect2=
  fi
  ret=$($cmd)
  if [ $? -ne $retval ]; then
      echo -e "\e[31m\nError in Test$testnr [$testname]:"
      echo -e "\e[0m:"
      exit -1
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

expecteq(){
  ret=$1
  expect=$2
  if [ -z "$ret" -a -z "$expect" ]; then
      return
  fi
  if [[ "$ret" = "$expect" ]]; then
      echo
  else
      err "$expect" "$ret"
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

