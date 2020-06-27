#!/usr/bin/env bash
#
# An effort to simplify the upgrading logic.
# The following simplifications have been made:
# 1) Just a single module defined with namespace "urn:example:interfaces"
# 2) Dont perform any upgrading actions, only look at modstate and revision dates
# Try to explore all possible cases, and ensure that the right upgrade functions are called
#
# Whats in the startup file (FROM) . There may be a revision date in the file called Y0.
# Whats loaded in the clixon backend (TO). There may be a revision date loaded called Y1.

# FROM: x-axis: this is how the module is marked in a startup file:
# no    : there is no modstate in the file                  (1)
# -     : there is modstate but module is not present       (2)
# Y0<Y1 : there is modstate and revision is earlier than Y1 (3)
# Y0=Y1 : there is modstate and revision is exactly Y1      (4)
# Y0>Y1 : there is modstate and revision is later than Y1   (5)
#
# TO: y-axis: the loaded YANG module in the backend:
# no : The module is not loaded
# Y1 : The module is loaded and has revision Y1
#
# A state diagram showing the different cases:
#-----------+--------+-------+-------+-------+-------+
# TOv FROM: |   no   |   -   | Y0<Y1 | Y0=Y1 | Y0>Y1 |
#-----------+--------+-------+-------+-------+-------+
#   no      |        |       |           x           |
#-----------+--------+-------+-------+-------+-------+
#   Y1      |        |       |   x   |       |   x   |
#-----------+--------+-------+-------+-------+-------+
#  TO

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/A@2016-01-01.yang
fyangb=$dir/B@2016-01-01.yang
log=$dir/backend.log
touch $log

# XXX Seems like clixon cant handle no Yang files (fix that seperately) which means
# there needs to be some "background" Yangs in the case when A is removed.
cat <<EOF > $fyangb
module B{
  prefix b;
  revision 2016-01-01;
  namespace "urn:example:b";
  container dummy{
  }
}
EOF

# Create configuration
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
</clixon-config>
EOF


# Create 5 startup files 1-5 according to the 5 cases above (columns in the matrix)
# Argument:
# 1: payload, eg whats in the config apart from modstate
createstartups()
{
    payload=$1

    # no  : there is no modstate in the file             (1)
    cat <<EOF > $dir/startup1.xml
<config>
   $payload
</config>
EOF

    # Create startup datastore:
    # -  : there is modstate but module is not present   (2)
    cat <<EOF > $dir/startup2.xml
<config>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
   </modules-state>
   $payload
</config>
EOF

    # Create startup datastore:
    # <Y : there is modstate and revision is less than Y (3)
    cat <<EOF > $dir/startup3.xml
<config>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>0814-01-28</revision>
         <namespace>urn:example:interfaces</namespace>
      </module>
   </modules-state>
   $payload
</config>
EOF

    # Create startup datastore:
    # =Y : there is modstate and revision is exactly Y   (4)
    cat <<EOF > $dir/startup4.xml
<config>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>2016-01-01</revision>
         <namespace>urn:example:interfaces</namespace>
      </module>
   </modules-state>
   $payload
</config>
EOF

    # Create startup datastore:
    # >Y : there is modstate and revision is exactly Y   (5)
    cat <<EOF > $dir/startup5.xml
<config>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>2018-01-01</revision>
         <namespace>urn:example:interfaces</namespace>
      </module>
   </modules-state>
   $payload
</config>
EOF
}


# Check statements in log
# arg1: a statement to look for
# arg2: expected line number
checklog(){
    s=$1 # statement
    l0=$2 # linenr
    new "Check $s in log on line $l0"
    t=$(grep -n "$s" $log)
    if [ -z "$t" ]; then
	echo -e "\e[31m\nError in Test$testnr [$testname]:"
	if [ $# -gt 0 ]; then 
	    echo "Not found in log"
	    echo
	fi
	echo -e "\e[0m"
	exit -1
    fi
    l1=$(echo "$t" | awk -F ":" '{print $1}')
    if [ $l1 -ne $l0 ]; then
	echo -e "\e[31m\nError in Test$testnr [$testname]:"
	if [ $# -gt 0 ]; then 
	    echo "Expected match on line $l0, found on $l1"
	    echo
	fi
	echo -e "\e[0m"
	exit -1
    fi
}

# Check statements are not in log
# arg1: a statement to look for
checknolog(){
    s=$1 # statement
    new "Check $s not in log"
#    echo "grep -n "$s" $log"
    t=$(grep -n "$s" $log)
#    echo "t:$t"
    if [ -n "$t" ]; then
	echo -e "\e[31m\nError in Test$testnr [$testname]:"
	if [ $# -gt 0 ]; then 
	    echo "$s found in log"
	    echo
	fi
	echo -e "\e[0m"
	exit -1
    fi
}

# Arguments:
# 1: from usecase 1-5
# 2: v: verb: true or false. The next statement should be there or not
# 3: what to look for in log (if v=true it should be there, if v=false it should not be there)
# 4: Linenr in log
testrun(){
    i=$1
    flag=$2
    match=$3
    line=$4
    
    cp $dir/startup$i.xml $dir/startup_db
    : > $log # truncate log
    new "test params: -f $cfg"
    # Bring your own backend
    if [ $BE -ne 0 ]; then
	# kill old backend (if any)
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s startup -f $cfg -l f$log -- -u"
	start_backend -s startup -f $cfg -l f$log  -- -u
	
	new "waiting"
	wait_backend
    fi

    if $flag; then
	checklog "$match" $line
    else
	checknolog "$match"
    fi
    
    if [ $BE -ne 0 ]; then
	new "Kill backend"
	# Check if premature kill
	pid=$(pgrep -u root -f clixon_backend)
	if [ -z "$pid" ]; then
	    err "backend already dead"
	fi
	# kill backend
	stop_backend -f $cfg
    fi
}

# Run through all tests with five different startups, with 5 tests with loaded YANG module A
# and then three tests without loaded YANG module A
# Input is different payloads
# Arguments:
# 1 : payload with loaded YANG
# 2 : payload without loaded YANG
testall()
{
    payload1=$1
    payload2=$2
    
    # Yang module with revision Y="2016-01-01"
    cat <<EOF > $fyang
module A{
  prefix a;
  revision 2016-01-01;
  namespace "urn:example:interfaces";
  container dummy{
  }
}
EOF
    createstartups "$payload1"
    
    # Y1 : The module is loaded and has revision Y
    new "1. module loaded, no modstate"
    testrun 1 false upgrade_interfaces

    new "2. module loaded, modstate but module absent"
    testrun 2 true "upgrade_interfaces urn:example:interfaces op:ADD from:0 to:20160101" 1

    new "3. module loaded, modstate with earlier date Y0<Y1"
    testrun 3 true "upgrade_interfaces urn:example:interfaces op:CHANGE from:8140128 to:20160101" 1

    new "4. module loaded, modstate with same date Y0=Y1"
    testrun 4 false "upgrade_interfaces"

    new "5. module loaded, modstate with later date Y0>Y1"
    testrun 5 true "upgrade_interfaces urn:example:interfaces op:CHANGE from:20180101 to:20160101" 1

    # LOAD: no : The module is not loaded
    # Yang module with revision Y="2016-01-01"
    rm -f $fyang
    createstartups "$payload2"
    
    new "1. module not loaded, no modstate"
    testrun 1 false upgrade_interfaces

    new "2. module not loaded, modstate but module absent"
    testrun 2 false upgrade_interfaces

    new "3. module not loaded, modstate with date Y1"
    testrun 3 true "upgrade_interfaces urn:example:interfaces op:DEL from:8140128 to:0" 1
}

# There is some issue with having different payloads in the config file
# That is why there are tests with different payloads

new "b payload only---------"
testall '<dummy xmlns="urn:example:b"/>' '<dummy xmlns="urn:example:b"/>'

new "b payload and interfaces payload---------"
testall '<dummy xmlns="urn:example:b"/><dummy xmlns="urn:example:interfaces"/>' '<dummy xmlns="urn:example:b"/>'

new "a payload only---------"
testall '<dummy xmlns="urn:example:interfaces"/>' ''

new "empty payload---------"
testall '' ''

rm -rf $dir

