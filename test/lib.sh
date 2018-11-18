#!/bin/bash
# Define test functions.
# Create working dir as variable "dir"

#set -e

testnr=0
testname=

# For memcheck
#clixon_cli="valgrind --leak-check=full --show-leak-kinds=all clixon_cli"
clixon_cli=clixon_cli

# For memcheck / performance
#clixon_netconf="valgrind --tool=callgrind clixon_netconf"
#clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
clixon_netconf=clixon_netconf

# How to run restconf stand-alone and using valgrind
#clixon_restconf="valgrind --trace-children=no --child-silent-after-fork=yes --leak-check=full --show-leak-kinds=all /www-data/clixon_restconf"
clixon_restconf=/www-data/clixon_restconf
RCWAIT=1 # Wait after restconf start. Set to 10 if valgrind

# If you test w valgrind, you need to set -F & and sleep 10 when starting
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
      echo
  fi
  if [ $# -gt 1 ]; then 
      echo "Received: $2"
  fi
  echo -e "\e[0m"
  echo "$ret"| od -t c > $dir/clixon-ret
  echo "$expect"| od -t c > $dir/clixon-expect
  diff $dir/clixon-expect $dir/clixon-ret 

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
#  echo "cmd:\"$cmd\""
#  echo "retval:\"$retval\""
#  echo "ret:\"$ret\""
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

# Pipe stdin to command
# Arguments:
# - Command
# - expected command return value (0 if OK)
# - stdin input
# - expected stdout outcome
expecteof(){
  cmd=$1
  retval=$2
  input=$3
  expect=$4

# Do while read stuff
ret=$($cmd<<EOF 
$input
EOF
)
  r=$? 
  if [ $r != $retval ]; then
      echo -e "\e[31m\nError ($r != $retval) in Test$testnr [$testname]:"
      echo -e "\e[0m:"
      exit -1
  fi
  # If error dont match output strings (why not?)
#  if [ $r != 0 ]; then
#      return
#  fi
  # Match if both are empty string
  if [ -z "$ret" -a -z "$expect" ]; then
      return
  fi
  match=`echo "$ret" | grep -GZo "$expect"`
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
  echo timeout > /tmp/flag
  ret=""
  sleep $wait |  cat <(echo $input) -| $cmd | while [ 1 ] ; do
    read -t 20 r
#    echo "r:$r"
    ret="$ret$r"
    match=$(echo "$ret" | grep -Eo "$expect");
    if [ -z "$match" ]; then
	echo error > /tmp/flag
	err "$expect" "$ret"
    else
	echo ok > /tmp/flag # only this is OK
	break;
    fi
  done
#  cat /tmp/flag
  if [ $(cat /tmp/flag) != "ok" ]; then
      cat /tmp/flag
      exit
  fi
}

