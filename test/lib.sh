#!/usr/bin/env bash
# Define test functions.
# See numerous configuration variables later on in this file that you can set
# in the environment or the site.sh file. The definitions in the site.sh file 
# override 
#
# Create working dir as variable "dir"
# The functions are somewhat wildgrown, a little too many:
# - expectpart
# - expecteof
# - expecteof_netconf
# - expecteofx
# - expecteofeq
# - expecteof_file
# - expectwait
# - expectmatch

#set -e
# : ${A=B} vs : ${A:=B} # colon also checks for NULL

# Testfile (not including path)
: ${testfile:=$(basename $0)}

# SKIPLIST lists the filenames of the test files that you do *not* want to run.
# The format is a whitespace separated list of filenames. Specify the SKIPLIST
# either in the shell environment or in the site.sh file. Any SKIPLIST specified
# in site.sh overrides a SKIPLIST specified in the environment. If not specified
# in either the environment or the site.sh, then the default SKIPLIST is empty.
: ${SKIPLIST:=""}

>&2 echo "Running $testfile"

# Generated config file from autotools / configure
if [ -f ./config.sh ]; then
    . ./config.sh
    if [ $? -ne 0 ]; then
	return -1 # error
    fi
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
# 4: Start valgrind every new snmp start. Check when snmp stops
# 
: ${valgrindtest=0}

# If set to 0, override starting of clixon_backend in test (you bring your own)
: ${BE:=1}

# If BE is set, some tests have a user timeout to show which params to set
# for starting a backend
: ${BETIMEOUT:=10}

# If set, enable debugging (of backend and restconf daemons)
: ${DBG:=0}

# If set to 0, override starting of clixon_restconf in test (you bring your own)
: ${RC:=1}

# Where to log restconf. Some systems may not have syslog,
# eg logging to a file: RCLOG="-l f/www-data/restconf.log"
: ${RCLOG:=}

# If set to 0, override starting of clixon_snmp in test (you bring your own)
: ${SN:=1}

# Namespace: netconf base
BASENS='urn:ietf:params:xml:ns:netconf:base:1.0'

# Namespace: Clixon config
CONFNS='xmlns="http://clicon.org/config"'

# Namespace: Clixon lib
LIBNS='xmlns="http://clicon.org/lib"'

# Namespace: Clixon restconf
RESTCONFNS='xmlns="http://clicon.org/restconf"'

# Default netconf namespace statement, typically as placed on top-level <rpc xmlns=""
DEFAULTONLY="xmlns=\"$BASENS\""

# Default netconf namespace + message-id
DEFAULTNS="$DEFAULTONLY message-id=\"42\""

# Minimal hello message as a prelude to netconf rpcs
DEFAULTHELLO="<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>"

# XXX cannot get this to work for all combinations of nc/netcat fcgi/native
# But leave it here for debugging where netcat works properly
if [ -n "$(type netcat 2> /dev/null)" ]; then
    netcat="netcat -w 1" # -N does not work on fcgi
# nc on freebsd does not work either
#elif [ -n "$(type nc 2> /dev/null)" ]; then
#    netcat=nc
else
    netcat=
fi

# SSL serv cert common name XXX should use DNS resolve
: ${SSLCN:="localhost"}

# Options passed to curl calls
# -s : silent
# -S : show error
# -i : Include HTTP response headers
# -k : insecure 
: ${CURLOPTS:="-Ssik"}
# Set HTTP version 1.1 or 2
if ${HAVE_LIBNGHTTP2}; then
    : ${HVER:=2}
else
    : ${HVER:=1.1}
fi

if [ ${HVER} = 2 ]; then
    if ${HAVE_HTTP1}; then
	# This is if http/1 is enabled (unset proto=HTTP_2 in restconf_accept_client)
	CURLOPTS="${CURLOPTS} --http2"
    else
	# This is if http/1 is disabled (set proto=HTTP_2 in restconf_accept_client)
	CURLOPTS="${CURLOPTS} --http2-prior-knowledge"
    fi
else
    CURLOPTS="${CURLOPTS} --http1.1"
fi

# Wait after daemons (backend/restconf) start. See mem.sh for valgrind
if [ "$(uname -m)" = "armv7l" ]; then
    : ${DEMWAIT:=8}
else
    : ${DEMWAIT:=2}
fi

# Multiplication factor to sleep less than whole seconds
DEMSLEEP=0.2

# Some sleep implementations cannot handle sub-seconds, change to 1s
sleep $DEMSLEEP || DEMSLEEP=1

# DEMWAIT is expressed in seconds, but really * DEMSLEEP
let DEMLOOP=5*DEMWAIT

# RESTCONF protocol, eg http or https

if [ "${WITH_RESTCONF}" = "fcgi" ]; then
    : ${RCPROTO:=http}
else
    : ${RCPROTO:=https}
fi

# www user (on linux typically www-data, freebsd www)
# Start restconf user, can be root which is dropped to wwwuser
: ${wwwstartuser:=root} 

# Some restconf tests can run IPv6, but its complicated because:
# - docker by default does not run IPv6
: ${IPv6:=false}

# Backend user
BUSER=clicon

# If set, unknown XML is treated as ANYDATA
# This would only happen if you set option YANG_UNKNOWN_ANYDATA to something else than default
: ${YANG_UNKNOWN_ANYDATA:=false}

# Follow the binary programs that can be parametrized (eg with valgrind)

: ${clixon_cli:=clixon_cli}

: ${clixon_netconf:=$(which clixon_netconf)}

: ${clixon_restconf:=clixon_restconf}

: ${clixon_backend:=clixon_backend}

: ${clixon_snmp:=$(type -p clixon_snmp)}

: ${clixon_snmp_pidfile:="/var/tmp/clixon_snmp.pid"}

# Temporary debug var, set to trigger remaining snmp errors
: ${snmp_debug:=false}

# Source the site-specific definitions for test script variables, if site.sh
# exists. The variables defined in site.sh override any variables of the same
# names in the environment in the current execution.
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

# Standard IETF RFC yang files. 
if [ ! -z ${YANG_STANDARD_DIR} ]; then
    : ${IETFRFC=$YANG_STANDARD_DIR/ietf/RFC}
fi

: ${SNMPCHECK:=true}

if $SNMPCHECK; then
    snmpget="$(type -p snmpget) -On -c public -v2c localhost "
    snmpbulkget="$(type -p snmpbulkget) -On -c public -v2c localhost "
    snmpset="$(type -p snmpset) -On -c public -v2c localhost "
    snmpgetstr="$(type -p snmpget) -c public -v2c localhost "
    snmpgetnext="$(type -p snmpgetnext) -On -c public -v2c localhost "
    snmpgetnextstr="$(type -p snmpgetnext) -c public -v2c localhost "
    snmptable="$(type -p snmptable) -c public -v2c localhost "
    snmpwalk="$(type -p snmpwalk) -c public -v2c localhost "
    snmptranslate="$(type -p snmptranslate) "

    if [ "${ENABLE_NETSNMP}" == "yes" ]; then
	    pgrep snmpd > /dev/null
        if [ $? != 0 ]; then
		    echo -e "\e[31m\nenable-netsnmp set but snmpd not running, start with:"
		    echo "systemctl start snmpd"
            echo ""
            echo "snmpd must be configured to use a Unix socket for agent communication"
            echo "and have a rwcommunity configured, make sure the following lines are"
            echo "added to /etc/snmp/snmpd.conf:"
            echo ""
            echo "  rwcommunity     public  localhost"
            echo "  agentXSocket    unix:/var/run/snmp.sock"
            echo "  agentxperms     777 777"
            echo ""
            echo "If you don't rely on systemd you can configure the lines above"
            echo "and start snmpd manually with 'snmpd -Lo -p /var/run/snmpd.pid'."
		    echo -e "\e[0m"
		    exit -1
        fi
    fi

    function validate_oid(){
        oid=$1
        oid2=$2
        type=$3
        value=$4
        result=$5

        name="$($snmptranslate $oid)"
        name2="$($snmptranslate $oid2)"

        if [[ $oid =~ ^([0-9]|\.)+$ ]]; then
            get=$snmpget
            getnext=$snmpgetnext
        else
            get=$snmpgetstr
            getnext=$snmpgetnextstr
        fi

        if [ $oid == $oid2 ]; then
            if [ -z "$result" ]; then
                result="$oid = $type: $value"
            fi

            new "Validating OID: $oid2 = $type: $value"
            expectpart "$($get $oid)" 0 "$result"
        else
            if [ -z "$result" ]; then
                result="$oid2 = $type: $value"
            fi

            new "Validating next OID: $oid2 = $type: $value"
            expectpart "$($getnext $oid)" 0 "$result"
        fi
    }
fi

# Check sanity between --with-restconf setting and if nginx is started by systemd or not
# This check is optional because some installs, such as vagrant make a non-systemd/direct
# start
: ${NGINXCHECK:=false}
# Sanity nginx running on systemd platforms
if $NGINXCHECK; then
    if systemctl > /dev/null 2>&1 ; then
	# even if systemd exists, nginx may be started in other ways
	nginxactive=$(systemctl show nginx |grep ActiveState=active)
	if [ "${WITH_RESTCONF}" = "fcgi" ]; then
	    if [ -z "$nginxactive"  -a ! -f /var/run/nginx.pid ]; then
		echo -e "\e[31m\nwith-restconf=fcgi set but nginx not running, start with:"
		echo "systemctl start nginx"
		echo -e "\e[0m"
		exit -1
	    fi
	else
	    if [ -n "$nginxactive" -o -f /var/run/nginx.pid ]; then
		echo -e "\e[31m\nwith-restconf=fcgi not set but nginx running, stop with:"
		echo "systemctl stop nginx"
		echo -e "\e[0m"
		exit -1
	    fi
	fi
    fi # systemctl
fi

# Temp directory where all tests write their data to
dir=/var/tmp/$0
if [ ! -d $dir ]; then
    mkdir $dir
fi

# Default restconf configuration: IPv4 
# Can be placed in clixon-config
# Note that https clause assumes there exists certs and keys in /etc/ssl,...
# Args:
# 1: auth-type (one of none, client-cert, user)
# 2: pretty (if true pretty-print restconf return values)
# [3: proto: http or https]
# [4: http_data: true or false] # Note feature http-data must be enabled
# Note, if AUTH=none then FEATURE clixon-restconf:allow-auth-none must be enabled
# Note if https, check if server cert/key exists, if not generate them
function restconf_config()
{
    AUTH=$1
    PRETTY=$2

    # Change this to fixed parameters
    if [ $# -gt 2 ]; then
	myproto=$3
    else
    	myproto=$RCPROTO
    fi
    if [ $# -gt 3 ]; then
	myhttpdata=$4
    else
    	myhttpdata=false
    fi
    
    echo -n "<CLICON_FEATURE>clixon-restconf:fcgi</CLICON_FEATURE>"
    if [ $myproto = http ]; then
	echo -n "<restconf><enable>true</enable>"
	if ${myhttpdata}; then
	    echo -n "<enable-http-data>true</enable-http-data>"
	fi
	echo "<auth-type>$AUTH</auth-type><pretty>$PRETTY</pretty><debug>$DBG</debug><socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket></restconf>"
    else
	certdir=$dir/certs
	if [ ! -f ${dir}/clixon-server-crt.pem ]; then
	    certdir=$dir/certs
	    test -d $certdir || mkdir $certdir
	    srvcert=${certdir}/clixon-server-crt.pem
	    srvkey=${certdir}/clixon-server-key.pem
	    cacert=${certdir}/clixon-ca-crt.pem
	    cakey=${certdir}/clixon-ca-key.pem
	    cacerts $cakey $cacert
	    servercerts $cakey $cacert $srvkey $srvcert
	fi
	echo -n "<restconf><enable>true</enable>"
	if ${myhttpdata}; then
	    echo -n "<enable-http-data>true</enable-http-data>"
	fi
	echo "<auth-type>$AUTH</auth-type><pretty>$PRETTY</pretty><server-cert-path>${certdir}/clixon-server-crt.pem</server-cert-path><server-key-path>${certdir}/clixon-server-key.pem</server-key-path><server-ca-cert-path>${certdir}/clixon-ca-crt.pem</server-ca-cert-path><debug>$DBG</debug><socket><namespace>default</namespace><address>0.0.0.0</address><port>443</port><ssl>true</ssl></socket></restconf>"
    fi
}

# Default autocli configuration
# Can be placed in clixon-config
# Exclude all modules instead as defined by arg1
# Args:
# 1: modname module name pattern to be included
# 2: list-keyword
# 3: treerefstate
function autocli_config()
{
    modname=$1
    listkw=$2
    state=$3

    TMP=$(cat <<EOF
  <autocli>
     <module-default>false</module-default>
     <list-keyword-default>$listkw</list-keyword-default>
     <treeref-state-default>$state</treeref-state-default>
     <rule>
       <name>include $modname</name>
       <operation>enable</operation>
       <module-name>$modname</module-name>
     </rule>
  </autocli>
EOF
   )
   echo "${TMP}"
}

# Some tests may set owner of testdir to something strange and quit, need
# to reset to me
if [ ! -G $dir ]; then 
    u=$(whoami)
    sudo chown $u $dir
    sudo chgrp $u $dir
fi

# If you bring your own backend BE=0 (it is already started), the backend may
# have created some files (eg unix socket) in $dir and therefore cannot
# be deleted.
# Same with RC=0
if [ $BE -ne 0 -a $RC -ne 0 ]; then
    rm -rf $dir/*
fi

# error and exit,
# arg1: expected
# arg2: errmsg[optional]
# Assumes: $dir and $expect are set
# see err1
function err(){
  echo -e "\e[31m\nError in Test$testnr [$testname]:"
  if [ $# -gt 0 ]; then 
      echo "Expected: $1"
      echo
  fi
  if [ $# -gt 1 ]; then 
      echo "Received: $2"
  fi
  echo -e "\e[0m"
  echo "Diff between Expected and Received:"
  diff <(echo "$ret"| od -t c) <(echo "$expect"| od -t c)

  exit -1 #$testnr
}

# Dont print diffs
function err1(){
  echo -e "\e[31m\nError in Test$testnr [$testname]:"
  if [ $# -gt 0 ]; then 
      echo "Expected: $1"
      echo
  fi
  if [ $# -gt 1 ]; then 
      echo "Received: $2"
  fi
  echo -e "\e[0m"
  exit -1 #$testnr
}

# Test is previous test had valgrind errors if so quit
function checkvalgrind(){
    if [ -f $valgrindfile ]; then
	res=$(cat $valgrindfile | grep -e "Invalid" |awk '{print  $4}' | grep -v '^0$')
	if [ -n "$res" ]; then
	    >&2 cat $valgrindfile
	    sudo rm -f $valgrindfile
	    exit -1	    
	fi
	res=$(cat $valgrindfile | grep -e "reachable" -e "lost:"|awk '{print  $4}' | grep -v '^0$')
	if [ -n "$res" ]; then
	    >&2 cat $valgrindfile
	    sudo rm -f $valgrindfile
	    exit -1	    
	fi
	sudo rm -f $valgrindfile
    fi
}

# Check if two RFC6242 NETCONF frames are equal
# Since they use \n you cannot just use =
function chunked_equal()
{
    echo "1:$1"
    echo "2:$2"
    if [ "$1" == "$2" ]; then
	return 0
    else
	return 255
    fi
}

# Given a string, add RFC6242 chunked franing around it
# Args:
# 0: string
function chunked_framing()
{
    str=$1
    length=${#str}
   
    printf "\n#%s\n%s\n##\n" ${length} "${str}"
}

# Start clixon_snmp
function start_snmp(){
    cfg=$1

    rm -f ${clixon_snmp_pidfile}
    
    $clixon_snmp -f $cfg -D $DBG &

    if [ $? -ne 0 ]; then
	    err
    fi
}

# Stop clixon_snmp and Valgrind if needed
function stop_snmp(){
    if [ $valgrindtest -eq 4 ]; then 
	pkill -f clixon_snmp
	sleep 1
	checkvalgrind
    else
	killall -q clixon_snmp
    fi
    rm -f ${clixon_snmp_pidfile}
}

# Start backend with all varargs.
# If valgrindtest == 2, start valgrind
function start_backend(){
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

function stop_backend(){
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
function wait_backend(){
    freq=$(chunked_framing "<rpc $DEFAULTNS><ping $LIBNS/></rpc>")
    reply=$(echo "$freq" | $clixon_netconf -q1ef $cfg) 
#    freply=$(chunked_framing "<rpc-reply $DEFAULTNS><ok/></rpc-reply>")
#    chunked_equal "$reply" "$freply"
    let i=0;
    while [[ $reply != *"<rpc-reply"* ]]; do
#	echo "sleep $DEMSLEEP"
	sleep $DEMSLEEP
	reply=$(echo "<rpc $ÐEFAULTSNS $LIBNS><ping/></rpc>]]>]]>" | clixon_netconf -qef $cfg 2> /dev/null)
#	echo "reply:$reply"
	let i++;
#	echo "wait_backend  $i"
	if [ $i -ge $DEMLOOP ]; then
	    err "backend timeout $DEMWAIT seconds"
	fi
    done
}

# Start restconf daemon
# @see wait_restconf
function start_restconf(){
    # Start in background 
    echo "sudo -u $wwwstartuser -s $clixon_restconf $RCLOG -D $DBG $*"
    sudo -u $wwwstartuser -s $clixon_restconf $RCLOG -D $DBG $* &
    if [ $? -ne 0 ]; then
	err1 "expected 0" "$?"
    fi
}

# Stop restconf daemon before test
function stop_restconf_pre(){
    sudo pkill -f clixon_restconf
}

# Stop restconf daemon after test
# Some problems with pkill:
# 1) Dont use $clixon_restconf (dont work in valgrind)
# 2) Dont use -u $WWWUSER since clixon_restconf may drop privileges.
# 3) After fork, it seems to take some time before name is right
function stop_restconf(){
    sudo pkill -f clixon_restconf
    if [ $valgrindtest -eq 3 ]; then 
	sleep 1
	checkvalgrind
    fi
}

# Wait for restconf to stop sending  502 Bad Gateway
# @see start_restconf
# Reasons for not working: if you run native is nginx running?
# @note assumes port=80 if RCPROTO=http and port=443 if RCPROTO=https
# Args:
# 1: (optional) override RCPROTO with http or https
function wait_restconf(){
    if [ $# = 1 ]; then
	myproto=$1
    else
	myproto=${RCPROTO}
    fi
#    echo "curl $CURLOPTS -X GET $myproto://localhost/restconf"
    hdr=$(curl $CURLOPTS -X GET $myproto://localhost/restconf 2> /dev/null)
#    echo "hdr:\"$hdr\""
    let i=0;
    while [[ "$hdr" != *"200"* ]]; do
#	echo "wait_restconf $i"
	if [ $i -ge $DEMLOOP ]; then
	    err1 "restconf timeout $DEMWAIT seconds"
	fi
	sleep $DEMSLEEP
#	echo "curl $CURLOPTS -X GET $myproto://localhost/restconf"
	hdr=$(curl $CURLOPTS -X GET $myproto://localhost/restconf 2> /dev/null)
#	echo "hdr:\"$hdr\""
	let i++;
    done
    if [ $valgrindtest -eq 3 ]; then 
	sleep 2 # some problems with valgrind
    fi
}

# Wait for restconf to stop 
# @note assumes port=80 if RCPROTO=http and port=443 if RCPROTO=https
# @see wait_restconf
function wait_restconf_stopped(){
#    echo "curl $CURLOPTS $* $RCPROTO://localhost/restconf"
    hdr=$(curl $CURLOPTS $* $RCPROTO://localhost/restconf 2> /dev/null)
#    echo "hdr:\"$hdr\""
    let i=0;
    while [[ $hdr = *"200 OK"* ]]; do
#	echo "wait_restconf_stopped $i"
	if [ $i -ge $DEMLOOP ]; then
	    err1 "restconf timeout $DEMWAIT seconds"
	fi
	sleep $DEMSLEEP
	hdr=$(curl $CURLOPTS $* $RCPROTO://localhost/restconf 2> /dev/null)
#	echo "hdr:\"$hdr\""
	let i++;
    done
    if [ $valgrindtest -eq 3 ]; then 
	sleep 2 # some problems with valgrind
    fi
}

# Use pidfile to check snmp started. pidfile is created after init in clixon_snmp
function wait_snmp()
{
    let i=0;
    while [ ! -f ${clixon_snmp_pidfile} ]; do
	if [ $i -ge $DEMLOOP ]; then
	    err1 "snmp timeout $DEMWAIT seconds"
	fi
	sleep $DEMSLEEP
	let i++;
    done
}
    
# End of test, final tests before normal exit of test
# Note this is a single test started by new, not a total test suite
function endtest()
{
    if [ $valgrindtest -eq 1 ]; then 
	checkvalgrind
    fi
}

# Increment test number and print a nice string
function new(){
    endtest # finalize previous test
    testnr=`expr $testnr + 1`
    testi=`expr $testi + 1`
    testname=$1
    >&2 echo "Test $testi($testnr) [$1]"
}

# End of complete test-suite, eg a test file
function endsuite()
{
    unset CURLOPTS
}

# Evaluate and return
# Example: expectpart $(fn arg) 0 "my return" -- "foo"
# - evaluated expression
# - expected command return value (0 if OK) or list of values, eg "55 56"
# - expected stdout outcome*
# - the token "--not--"
# - not expected stdout outcome*
# Example:
# expectpart "$(a-shell-cmd arg)" 0 'expected match 1' 'expected match 2' --not-- 'not expected 1'
# @note need to escape \[\]
function expectpart(){
  r=$?
  ret=$1
  retval=$2
  expect=$3

#  echo "r:$r"
#  echo "ret:\"$ret\""
#  echo "retval:$retval"
#  echo "expect:\"$expect\""
  if [ "$retval" -eq "$retval" 2> /dev/null ] ; then # single retval
      if [ $r != $retval ]; then 
	  echo -e "\e[31m\nError ($r != $retval) in Test$testnr [$testname]:"
	  echo -e "\e[0m:"
	  exit -1
      fi
  else # List of retvals
      found=0
      for rv in $retval; do
	  if [ $r == $rv ]; then 
	      found=1
	  fi
      done
      if [ $found -eq 0 ]; then
	  echo -e "\e[31m\nError ($r != $retval) in Test$testnr [$testname]:"
	  echo -e "\e[0m:"
	  exit -1
      fi
  fi
  if [ -z "$ret" -a -z "$expect" ]; then
      return
  fi
  # Loop over all variable args expect strings (skip first two args)
  # note that "expect" var is never actually used
  # Then test positive for strings, if the token --not-- is detected, then test negative for the rest
  positive=true;
  let i=0;
  for exp in "$@"; do
      if [ $i -gt 1 ]; then
	  if [ "$exp" == "--not--" ]; then
	      positive=false;
	  else
#	   echo "echo \"$ret\" | grep --null -o \"$exp"\"
	      match=$(echo "$ret" | grep --null -i -o "$exp") #-i ignore case XXX -EZo: -E cant handle {}
	      r=$? 
	      if $positive; then
		  if [ $r != 0 ]; then
		      err "$exp" "$ret"
		  fi
	      else
		  if [ $r == 0 ]; then
		      err "not $exp" "$ret"
		  fi
	      fi
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
# - expected command return value (0 if OK) XXX SHOULD SWITCH w next
# - stdin input
# - expected stdout outcome
# - expected stderr outcome (can be null)
# Use this if you want regex eg  ^foo$
function expecteof(){
  cmd=$1
  retval=$2
  input=$3
  expect=$4
  if [ $# -gt 4 ]; then
      errfile=$(mktemp)
      expecterr=$5
# Do while read stuff
      ret=$($cmd 2> $errfile <<EOF 
$input
EOF
	 )
      r=$? 
  else
# Do while read stuff
      ret=$($cmd <<EOF 
$input
EOF
 )
  r=$? 
  fi
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
      : # null
  else
      # -G for basic regexp (eg ^$). -E for extended regular expression - differs in \
	  # --null for nul character, -x for implicit ^$ -q for quiet
      # -o only matching
      # Two variants: --null -Eo and -Fxq
      #  match=`echo "$ret" | grep --null -Fo "$expect"`
      if [ $# -gt 4 ]; then # stderr
	  rerr=$(cat $errfile)
	  rm -f $errfile
	  r=$(echo "$rerr" | grep --null -Go "$expecterr")
	  match=$?
	  if [ $match -ne 0 ]; then
	      err "$expecterr" "$rerr"
	  fi
      fi

      r=$(echo "$ret" | grep --null -Go "$expect")
      match=$?

#  echo "r:\"$r\""
#  echo "ret:\"$ret\""
#  echo "expect:\"$expect\""
#  echo "match:\"$match\""
      if [ $match -ne 0 ]; then
	  err "$expect" "$ret"
      fi
  fi
}

# Pipe stdin to command and also do chunked framing (netconf 1.1)
# Arguments:
# - Command
# - expected command return value (0 if OK)
# - stdin input1  This is NOT encoded, eg preamble/hello
# - stdin input2  This gets chunked encoding
# - expect1 stdout outcome, can be partial and contain regexps
# - expect2 stdout outcome This gets chunked encoding, must be complete netconf message
# Use this if you want regex eg  ^foo$
function expecteof_netconf(){
  cmd=$1
  retval=$2
  input1=$3
  input2=$4
  expect1=$5
  expect2=$6

  if [ -n "${input2}" ]; then
      inputenc=$(chunked_framing "${input2}")
  else
      inputenc=""
  fi
  if [ -n "${expect2}" ]; then
      expectenc=$(chunked_framing "${expect2}")
  else
      expectenc=""
  fi

#  echo "input1:$input1"
#  echo "input2:$input2"
#  echo "inputenc:$inputenc"
#  echo "expect1:$expect1"
#  echo "expect2:$expect2"
#  echo "expectenc:$expectenc"
# Do while read stuff
  ret=$($cmd <<EOF 
${input1}${inputenc}
EOF
 )
  r=$? 

  if [ $r != $retval ]; then
      echo -e "\e[31m\nError ($r != $retval) in Test$testnr [$testname]:"
      echo -e "\e[0m:"
      exit -1
  fi
  # If error dont match output strings (why not?)
  # Match if both are empty string
  if [ -z "$ret" -a -z "$expect1" ]; then
      : # null
  else
      r=$(echo "$ret" | grep --null -Go "$expect1")
      match=$?
      if [ $match -ne 0 ]; then
	  err "$expect1" "$ret"
      fi
  fi
  if [ -z "$ret" -a -z "$expectenc" ]; then
      : # null
  else
      while read i
      do
	  r=$(echo "$ret" | grep --null -Go "$i")
	  match=$?
	  if [ $match -ne 0 ]; then
	      err "$expectenc" "$ret"
	  fi
      done <<< "$expectenc"
  fi
}

# Like expecteof but with grep -Fxq instead of -EZq. Ie implicit ^$
# Use this for fixed all line, ie must match exact.
# - Command
# - expected command return value (0 if OK)
# - stdin input
# - expected stdout outcome
function expecteofx(){
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
# # - Command
# - expected command return value (0 if OK)
# - stdin input
# - expected stdout outcome
function expecteofeq(){
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
# Arguments:
# - Command
# - Filename to pipe to stdin 
# - expected stdout outcome
function expecteof_file(){
  cmd=$1
  retval=$2
  file=$3
  expect=$4

  # Run the command, pipe stdin from file
  ret=$($cmd<$file)
  r=$?
  if [ $r != $retval ]; then
      echo -e "\e[31m\nError ($r != $retval) in Test$testnr [$testname]:"
      echo -e "\e[0m:"
      exit -1
  fi
  # Match if both are empty string
  if [ -z "$ret" -a -z "$expect" ]; then
      return
  fi
  match=`echo "$ret" | grep -Eo "$expect"`
  if [ -z "$match" ]; then
      err "$expect" "$ret"
  fi
}

# test script with timeout, used for notificatin streams
# - (not-evaluated) expression
# - expected command return value (0 if OK) (NOOP for now)
# - stdin input1  This is NOT encoded, eg preamble/hello
# - stdin input2  This gets chunked encoding
# - wait time in seconds
# - expected stdout outcome*
# - the token "--not--"
# - not expected stdout outcome*
#
# Note: use of a file "result" as a way to collect results
function expectwait(){
  cmd=$1
  ret=$2
  input1=$3
  input2=$4
  wait=$5
  expect=$6

  if [ -n "${input2}" ]; then
      inputenc=$(chunked_framing "${input2}")
  else
      inputenc=""
  fi
#  echo "cmd:$cmd"
#  echo "ret:$ret"
#  echo "input1:$input1"
#  echo "inputenc:$inputenc"
#  echo "wait:$wait"
#  echo "expect:$expect"
# Do while read stuff
  echo timeout > $dir/expectwaitresult
  ret=""
  sleep $wait | cat <(echo "$input1$inputenc") -| $cmd | while [ 1 ] ; do
    read -t 20 r
#    echo "r:<$r>"
    if [ -z "$r" ]; then
	sleep 1
	continue
    fi
    # Append $r to $ret
    ret="$ret$r"
#    echo "ret:$ret"
    let i=0;
    positive=true;
    let ok=0
    let fail=0
    for exp in "$@"; do
	if [ $i -gt 4 ]; then
#	    echo "i:$i"
#	    echo "exp:$exp"
	    if [ "$exp" == "--not--" ]; then
		positive=false;
	    else
		match=$(echo "$ret" | grep --null -i -o "$exp")
#		match=$(echo "$ret" | grep -Eo "$exp");
		r=$?
		if $positive; then
		    if [ $r != 0 ]; then
#			echo "fail: $exp"
			let fail++
			break
		    fi
		else
		    if [ $r == 0 ]; then
#			echo "fail: $exp"
			let fail++
			break
		    fi
		fi
	    fi
	fi
	let i++;
    done # for exp
#    echo "fail:$fail"
    if [ $fail -eq 0 ]; then
#	echo ok
	echo ok > $dir/expectwaitresult	
	#	break
	exit 0
    fi
  done
#  cat $dir/expectwaitresult
  if [ $(cat $dir/expectwaitresult) != "ok" ]; then
      err "ok" "$(cat $dir/expectwaitresult)"
      cat $dir/expectwaitresult
      exit -1
  fi
}

function expectmatch(){
    ret=$1
    r=$2
    expret=$3
    expect=$4
#    echo "ret:$ret"
#    echo "ret:$r"
#    echo "expret:$expret"
#    echo "expect:$expect"
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
	    match=`echo "$ret" | grep --null -Eo "$expect2"`
	    if [ -z "$match" ]; then
		err $expect "$ret"
	    fi
	fi
    fi
}

# Create CA certs
# Output variables set as filenames on entry, set as cert/keys on exit:
# Vars:
# 1: cakey   filename
# 2: cacert  filename
function cacerts()
{
    if [ $# -ne 2 ]; then
	echo "cacerts function: Expected: cakey cacert"
	exit 1
    fi
    local cakey=$1
    local cacert=$2

    tmpdir=$dir/tmpcertdir

    test -d $tmpdir || mkdir $tmpdir

    # 1. CA
    cat<<EOF > $tmpdir/ca.cnf
[ ca ]
default_ca      = CA_default

[ CA_default ]
serial = ca-serial
crl = ca-crl.pem
database = ca-database.txt
name_opt = CA_default
cert_opt = CA_default
default_crl_days = 9999
default_md = md5

[ req ]
default_bits           = ${CERTKEYLEN}
days                   = 1
distinguished_name     = req_distinguished_name
attributes             = req_attributes
prompt                 = no
output_password        = password

[ req_distinguished_name ]
C                      = SE
L                      = Stockholm
O                      = Clixon
OU                     = clixon
CN                     = ca
emailAddress           = olof@hagsand.se

[ req_attributes ]
challengePassword      = test

EOF

    # Generate CA cert
    openssl req -x509 -days 1 -config $tmpdir/ca.cnf -keyout $cakey -out $cacert || err "Generate CA cert"

    rm -rf $tmpdir
}

# Create server certs
# Output variables set as filenames on entry, set as cert/keys on exit:
# Vars:
# 1: cakey   filename (input)
# 2: cacert  filename (input)
# 3: srvkey  filename (output)
# 4: srvcert filename (output)
function servercerts()
{
    if [ $# -ne 4 ]; then
	echo "servercerts function: Expected: cakey cacert srvkey srvcert"
	exit 1
    fi
    cakey=$1
    cacert=$2
    srvkey=$3
    srvcert=$4

    tmpdir=$dir/tmpcertdir

    test -d $tmpdir || mkdir $tmpdir

    cat<<EOF > $tmpdir/srv.cnf
[req]
prompt = no
distinguished_name = dn
req_extensions = ext
[dn]
CN = ${SSLCN} # localhost
emailAddress = olof@hagsand.se
O = Clixon
L = Stockholm
C = SE
[ext]
subjectAltName = DNS:clicon.org
EOF

    # Generate server key
    openssl genpkey -algorithm RSA -out $srvkey  || err "Generate server key"

    # Generate CSR (signing request)
    openssl req -new -config $tmpdir/srv.cnf -key $srvkey -out $tmpdir/srv_csr.pem || err "Generate signing request"

    # Sign server cert by CA
    openssl x509 -req -extfile $tmpdir/srv.cnf -days 1 -passin "pass:password" -in $tmpdir/srv_csr.pem -CA $cacert -CAkey $cakey -CAcreateserial -out $srvcert || err "Sign server cert"

    rm -rf $tmpdir
}

