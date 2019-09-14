#!/bin/bash
# Define test functions.
# Create working dir as variable "dir"
# The functions are somewhat wildgrown, a little too many:
# - expectfn
# - expecteq
# - expecteof
# - expecteofx
# - expecteof_file
# - expectwait
# - expectmatch

#set -e
# : ${A=B} vs : ${A:=B} # colon also checks for NULL

# Testfile (not including path)
: ${testfile:=$(basename $0)}

# Add test to this list that you dont want run
# Typically add them in your site file
: ${SKIPLIST:=""}

# Some tests (openconfig/yang_models) just test for the cli to return a version
version=4

>&2 echo "Running $testfile"

# Site file, an example of this file in README.md
if [ -f ./site.sh ]; then
    . ./site.sh
    if [ $? -ne 0 ]; then
	return -1 # skip
    fi
    # test skiplist.
    for f in $SKIPLIST; do
	if [ "$testfile" = "$f" ]; then
	    echo "...skipped (see site.sh)"
	    return -1 # skip
	fi
    done
fi

# Test number from start
: ${testnr:=0}

# Test number in this test
testi=0

# Single test. Set by "new"
testname=

# Valgind memory leak check.
# The values are:
# 0: No valgrind check
# 1: Start valgrind at every new testcase. Check result every next new
# 2: Start valgrind every new backend start. Check when backend stops
# 3: Start valgrind every new restconf start. Check when restconf stops
# 
: ${valgrindtest=0}

# Valgrind log file. This should be removed automatically. Note that mktemp
# actually creates a file so do not call it by default
#: ${valgrindfile=$(mktemp)}

# If set to 0, override starting of clixon_backend in test (you bring your own)
: ${BE:=1}

# If BE is set, some tests have a user timeout to show which params to set
# for starting a backend
: ${BETIMEOUT:=10}

# If set, enable debugging (of backend)
: ${DBG:=0}

# Where to log restconf. Some systems may not have syslog,
# eg logging to a file: RCLOG="-l f/www-data/restconf.log"
: ${RCLOG:=}

# Wait after daemons (backend/restconf) start. See mem.sh for valgrind
: ${RCWAIT:=2} 

# Parse yangmodels from https://github.com/YangModels/yang
# Recommended: checkout yangmodels elsewhere in the tree and set the env
# to that
#: ${YANGMODELS=$(pwd)/yang} # just skip if not set

# Parse yang openconfig models from https://github.com/openconfig/public
#: ${OPENCONFIG=$(pwd)/public} # just skip if not set

# Standard IETF RFC yang files. 
: ${IETFRFC=../yang/standard}
#: ${IETFRFC=$YANGMODELS/standard/ietf/RFC}

# Backend user
BUSER=clicon

# Follow the binary programs that can be parametrized (eg with valgrind)

: ${clixon_cli:=clixon_cli}

: ${clixon_netconf:=clixon_netconf}

: ${clixon_restconf:=/www-data/clixon_restconf}

: ${clixon_backend:=clixon_backend}

dir=/var/tmp/$0
if [ ! -d $dir ]; then
    mkdir $dir
fi

# Some tests may set owner of testdir to something strange and quit, need
# to reset to me
if [ ! -G $dir ]; then 
    u=$(whoami)
    sudo chown $u $dir
    sudo chgrp $u $dir
fi

# If you bring your own backend BE=0 (it is already started),the backend may
# have created some files (eg unix socket) in $dir and therefore cannot
# be deleted
if [ $BE -ne 0 ]; then
    rm -rf $dir/*
fi

# error and exit,
# arg1: expected
# arg2: errmsg[optional]
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

  exit -1 #$testnr
}

# Test is previous test had valgrind errors if so quit
checkvalgrind(){
    if [ -f $valgrindfile ]; then
	res=$(cat $valgrindfile | grep -e "reachable" -e "lost:"|awk '{print  $4}' | grep -v '^0$')
	if [ -n "$res" ]; then
	    >&2 cat $valgrindfile
	    sudo rm -f $valgrindfile
	    exit -1	    
	fi
	sudo rm -f $valgrindfile
    fi
}

# Start backend with all varargs.
# If valgrindtest == 2, start valgrind
start_backend(){
    if [ $valgrindtest -eq 2 ]; then
	# Start in background since daemon version creates two traces: parent,
	# child. If background then only the single relevant.
	sudo $clixon_backend -F -D $DBG $* &
    else
	sudo $clixon_backend -D $DBG $*
    fi
    if [ $? -ne 0 ]; then
	err
    fi
}

stop_backend(){
    sudo clixon_backend -z $*
    if [ $? -ne 0 ]; then
	err "kill backend"
    fi
    if [ $valgrindtest -eq 2 ]; then 
	sleep 1
	checkvalgrind
    fi
    sudo pkill -f clixon_backend # extra ($BUSER?)
}

# Wait for restconf to stop sending  502 Bad Gateway
wait_backend(){
    reply=$(echo '<rpc message-id="101"><ping xmlns="http://clicon.org/lib"/></rpc>]]>]]>' | clixon_netconf -qef $cfg 2> /dev/null) 
    let i=0;
    while [[ $reply != "<rpc-reply"* ]]; do
	sleep 1
	reply=$(echo '<rpc message-id="101" xmlns="http://clicon.org/lib"><ping/></rpc>]]>]]>' | clixon_netconf -qef $cfg 2> /dev/null)
	let i++;
#	echo "wait_backend  $i"
	if [ $i -ge $RCWAIT ]; then
	    err "backend timeout $RCWAIT seconds"
	fi
    done
}

start_restconf(){
    # Start in background 
    sudo su -c "$clixon_restconf $RCLOG -D $DBG $*" -s /bin/sh www-data &
    if [ $? -ne 0 ]; then
	err
    fi
}

stop_restconf(){
    sudo pkill -u www-data -f "/www-data/clixon_restconf"
    if [ $valgrindtest -eq 3 ]; then 
	sleep 1
	checkvalgrind
    fi
}

# Wait for restconf to stop sending  502 Bad Gateway
wait_restconf(){
    hdr=$(curl --head -sS http://localhost/restconf)
    let i=0;
    while [[ $hdr == "HTTP/1.1 502 Bad Gateway"* ]]; do
	sleep 1
	hdr=$(curl --head -sS http://localhost/restconf)
	let i++;
#	echo "wait_restconf $i"
	if [ $i -ge $RCWAIT ]; then
	    err "restconf timeout $RCWAIT seconds"
	fi
    done
}

# Increment test number and print a nice string
new(){
    if [ $valgrindtest -eq 1 ]; then 
	checkvalgrind
    fi
    testnr=`expr $testnr + 1`
    testi=`expr $testi + 1`
    testname=$1
    >&2 echo "Test $testi($testnr) [$1]"
}

# clixon command tester.
# Arguments:
# - command,
# - expected command return value (0 if OK)
# - expected* stdout outcome, (can be many)
# Example: expectfn "$clixon_cli -1 -f $cfg show conf cli" 0 "line1" "line2" 
# XXX: for some reason some curl commands dont work here, eg
#   curl -H 'Accept: application/xrd+xml'
# instead use expectpart
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
    r=$?
#    echo "cmd:\"$cmd\""
#    echo "retval:\"$retval\""
#    echo "expect:\"$expect\""
#    echo "ret:\"$ret\""
#    echo "r:\"$r\""
    if [ $r != $retval ]; then
	echo -e "\e[31m\nError ($r != $retval) in Test$testnr [$testname]:"
	echo -e "\e[0m:"
	exit -1
    fi
    #  if [ $ret -ne $retval ]; then
    #      echo -e "\e[31m\nError in Test$testnr [$testname]:"
    #      echo -e "\e[0m:"
    #      exit -1
    #  fi
    # Match if both are empty string (special case)
    if [ -z "$ret" -a -z "$expect" ]; then
	return
    fi
    if [ -z "$ret" -a "$expect" = "^$" ]; then
	return
    fi
    # Loop over all variable args expect strings
    let i=0;
    for exp in "$@"; do
	if [ $i -gt 1 ]; then
	    match=`echo $ret | grep -EZo "$exp"`
	    if [ -z "$match" ]; then
		err "$exp" "$ret"
	    fi
	fi
	let i++;
	
    done
}

# Evaluate and return
# Example: expecteq $(fn arg) 0 "my return"
# - evaluated expression
# - expected command return value (0 if OK)
# - expected stdout outcome
expecteq(){
  r=$?
  ret=$1
  retval=$2
  expect=$3
#  echo "r:$r"
#  echo "ret:\"$ret\""
#  echo "retval:$retval"
#  echo "expect:$expect"
  if [ $r != $retval ]; then
      echo -e "\e[31m\nError ($r != $retval) in Test$testnr [$testname]:"
      echo -e "\e[0m:"
      exit -1
  fi
  if [ -z "$ret" -a -z "$expect" ]; then
      return
  fi
  if [[ "$ret" != "$expect" ]]; then
      err "$expect" "$ret"
  fi
}

# Evaluate and return
# like expecteq but partial match is OK
# Example: expecteq $(fn arg) 0 "my return"
# - evaluated expression
# - expected command return value (0 if OK)
# - expected stdout outcome
expectpart(){
  r=$?
  ret=$1
  retval=$2
  expect=$3
#  echo "r:$r"
#  echo "ret:\"$ret\""
#  echo "retval:$retval"
#  echo "expect:$expect"
  if [ $r != $retval ]; then
      echo -e "\e[31m\nError ($r != $retval) in Test$testnr [$testname]:"
      echo -e "\e[0m:"
      exit -1
  fi
  if [ -z "$ret" -a -z "$expect" ]; then
      return
  fi
  # Loop over all variable args expect strings
  let i=0;
  for exp in "$@"; do
       if [ $i -gt 1 ]; then
#      echo "exp:$exp"
	  match=`echo $ret | grep -Zo "$exp"` # XXX -EZo: -E cant handle {}
	  if [ -z "$match" ]; then
	      err "$exp" "$ret"
	  fi
      fi
      let i++;
    done

#  if [[ "$ret" != "$expect" ]]; then
#      err "$expect" "$ret"
#  fi
}


# Pipe stdin to command
# Arguments:
# - Command
# - expected command return value (0 if OK)
# - stdin input
# - expected stdout outcome
# Use this if you want regex eg  ^foo$
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
  # -G for basic regexp (eg ^$). -E for extended regular expression - differs in \
  # -Z for nul character, -x for implicit ^$ -q for quiet
  # -o only matching
  # Two variants: -EZo and -Fxq
  #  match=`echo "$ret" | grep -FZo "$expect"`
  r=$(echo "$ret" | grep -GZo "$expect")
  match=$?
#  echo "r:\"$r\""
#  echo "ret:\"$ret\""
#  echo "expect:\"$expect\""
#  echo "match:\"$match\""
  if [ $match -ne 0 ]; then
      err "$expect" "$ret"
  fi
}

# Like expecteof but with grep -Fxq instead of -EZq. Ie implicit ^$
# Use this for fixed all line, ie must match exact.
expecteofx(){
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
  # -E for regexp (eg ^$). -Z for nul character, -x for implicit ^$ -q for quiet
  # -o only matching
  # Two variants: -EZo and -Fxq
  #  match=`echo "$ret" | grep -FZo "$expect"`
  r=$(echo "$ret" | grep -Fxq "$expect")
  match=$?
#  echo "ret:\"$ret\""
#  echo "expect:\"$expect\""
#  echo "match:\"$match\""
  if [ $match -ne 0 ]; then
      err "$expect" "$ret"
  fi
}

# Like expecteof/expecteofx but with test == instead of grep.
# No wildcards
# Use this for multi-lines
expecteofeq(){
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
#  echo "ret:\"$ret\""
#  echo "expect:\"$expect\""
#  echo "match:\"$match\""
  if [ "$ret" != "$expect" ]; then
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
#      err "ok" $(cat /tmp/flag)
#      cat /tmp/flag
      exit -1
  fi
}

expectmatch(){
    ret=$1
    r=$2
    expret=$3
    expect=$4
    if [ $r != $expret ]; then
	echo -e "\e[31m\nError ($r != $retval) in Test$testnr [$testname]:"
	echo -e "\e[0m:"
	exit -1
    fi
    if [ -z "$ret" -a -z "$expect" ]; then
	echo > /dev/null
    else
	match=$(echo "$ret" | grep -Eo "$expect")
	if [ -z "$match" ]; then
	    err "$expect" "$ret"
	fi
	if [ -n "$expect2" ]; then
	    match=`echo "$ret" | grep -EZo "$expect2"`
	    if [ -z "$match" ]; then
		err $expect "$ret"
	    fi
	fi
    fi
}

