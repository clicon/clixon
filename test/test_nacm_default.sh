#!/usr/bin/env bash
# Basic NACM default rule without any groups
# Start from startup db

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang

# Which format to use as datastore format internally
: ${format:=xml}

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_CREDENTIALS>none</CLICON_NACM_CREDENTIALS>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
</clixon-config>
EOF

cat <<EOF > $fyang
module nacm-example{
  yang-version 1.1;
  namespace "urn:example:nacm";
  prefix nacm;
  import clixon-example {
	prefix ex;
  }
  import ietf-netconf-acm {
	prefix nacm;
  }
  leaf x{
    type int32;
    description "something to edit";
  }
}
EOF

# 
# startup db with default values: 
# 1: enable-nacm (true|false)
# 2: read-default (deny|permit)
# 3: write-default (deny|permit)
# 4: exec-defautl (deny|permit)
# 5: expected return value of test1
# 6: expected return value of test2
# 7: expected return value of test3
testrun(){
    enablenacm=$1
    readdefault=$2
    writedefault=$3
    execdefault=$4
    ret1=$5
    ret2=$6
    ret3=$7

    # NACM in startup
    sudo tee $dir/startup_db > /dev/null << EOF
    <config>
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>${enablenacm}</enable-nacm>
     <read-default>${readdefault}</read-default>
     <write-default>${writedefault}</write-default>
     <exec-default>${execdefault}</exec-default>
     <enable-external-groups>true</enable-external-groups>
   </nacm>
   <x xmlns="urn:example:nacm">42</x>
   </config>
EOF
    if [ $BE -ne 0 ]; then     # Bring your own backend
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s startup -f $cfg"
	start_backend -s startup -f $cfg
    else
	new "Restart backend as eg follows: -Ff $cfg -s startup"
	sleep $BETIMEOUT
    fi
    
    new "waiting"
    wait_backend
    
    new "kill old restconf daemon"
    sudo pkill -u $wwwuser -f clixon_restconf

    new "start restconf daemon (-a is enable basic authentication)"
    start_restconf -f $cfg -- -a

    new "waiting"
    wait_restconf
    
    #----------- First get
    case "$ret1" in
	0) ret='{"nacm-example:x":42}
'
	;;
	1) ret='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'
	   ;;
	2) ret='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'
	;;
    esac

    new "get startup 42"
    expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/nacm-example:x)" 0 "$ret"

    #----------- Then edit
    case "$ret2" in
	0) ret=''
	;;
	1) ret='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'
	;;
    esac
    new "edit new 99"
    expecteq "$(curl -u guest:bar -sS -X PUT -H "Content-Type: application/yang-data+json" -d '{"nacm-example:x": 99}' http://localhost/restconf/data/nacm-example:x)" 0 "$ret"

    #----------- Then second get
    case "$ret3" in
	0) ret='{"nacm-example:x":99}
'
	;;
	1) ret='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'
        ;;
	2) ret='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'
	   ;;
	3) ret='{"nacm-example:x":42}
'
    esac
    new "get 99"
    expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/nacm-example:x)" 0 "$ret"
    
    new "Kill restconf daemon"
    stop_restconf
    
    if [ $BE -ne 0 ]; then     # Bring your own backend
	new "Kill backend"
	# Check if premature kill
	pid=$(pgrep -u root -f clixon_backend)
	if [ -z "$pid" ]; then
	    err "backend already dead"
	fi
	# kill backend
	stop_backend -f $cfg
    fi
} # testrun

# Run a lot of tests with different settings of default read/write/exec
new "nacm enabled and all defaults permit"
testrun true permit permit permit 0 0 0

new "nacm disabled and all defaults permit"
testrun false permit permit permit 0 0 0

new "nacm disabled and all defaults deny"
testrun false deny deny deny 0 0 0

new "nacm enabled, all defaults deny (expect fail)"
testrun true deny deny deny 1 1 1

new "nacm enabled, exec default deny - read permit (expect fail)"
testrun true permit deny deny 1 1 1

new "nacm enabled, exec default deny - write permit (expect fail)"
testrun true deny permit deny 1 1 1

new "nacm enabled, exec default deny read/write permit (expect fail)"
testrun true permit permit deny 1 1 1

new "nacm enabled, exec default permit, all others deny (expect fail)"
testrun true deny deny permit 2 1 2

new "nacm enabled, exec default permit, read permit (expect fail)"
testrun true permit deny permit 0 1 3

new "nacm enabled, exec default permit, write permit (expect fail)"
testrun true deny permit permit 2 0 2

rm -rf $dir

# unset conditional parameters 
unset format
