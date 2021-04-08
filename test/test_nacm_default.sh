#!/usr/bin/env bash
# Basic NACM default rule without any groups
# Start from startup db as well as init db and load using POST

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang

# Which format to use as datastore format internally
: ${format:=xml}

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config user false)

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
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang
module nacm-example{
  yang-version 1.1;
  namespace "urn:example:nacm";
  prefix nex;
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
# 8: startup mode: startup or init
function testrun(){
    enablenacm=$1
    readdefault=$2
    writedefault=$3
    execdefault=$4
    ret1=$5
    ret2=$6
    ret3=$7
    db=$8

    NACM=$(cat <<EOF
    	       <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
	            <enable-nacm>${enablenacm}</enable-nacm>
		    <read-default>${readdefault}</read-default>
		    <write-default>${writedefault}</write-default>
		    <exec-default>${execdefault}</exec-default>
		    <enable-external-groups>true</enable-external-groups>
	       </nacm>
EOF
)
    # Initial data
    XML='<x xmlns="urn:example:nacm">42</x>'

    # Use startup or set values with POST (below)
    if [ $db = startup ]; then
	sudo echo "<${DATASTORE_TOP}>$NACM$XML</${DATASTORE_TOP}>" > $dir/startup_db
    fi

    if [ $BE -ne 0 ]; then     # Bring your own backend
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s $db -f $cfg"
	start_backend -s $db -f $cfg

	new "wait backend"
	wait_backend
    fi
    new "wait backend"
    wait_backend
    
    if [ $RC -ne 0 ]; then     # Bring your own restconf
	new "kill old restconf daemon"
	stop_restconf_pre

	new "start restconf daemon"
	start_restconf -f $cfg
    fi
    new "wait restconf"
    wait_restconf

    # Use  POST (instead of startup)
    # Note this only works because CLICON_NACM_DISABLED_ON_EMPTY is true
    if [ $db = init ]; then
	# Must set NACM first
	new "Set NACM using PATCH"
	expectpart "$(curl -u guest:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+xml" -d "<data>$NACM$XML</data>" $RCPROTO://localhost/restconf/data)" 0 "HTTP/1.1 201 Created"

#	new "Set Initial data using POST"
#	expectpart "$(curl -u guest:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" -d "$XML" $RCPROTO://localhost/restconf/data)" 0 "HTTP/1.1 201 Created"
	

    fi
    
    #----------- First get
    case "$ret1" in
	0) ret='{"nacm-example:x":42}'
	   status="HTTP/1.1 200 OK"
	;;
	1) ret='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'
	   status="HTTP/1.1 403 Forbidden"
	   ;;
	2) ret='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'
	   status="HTTP/1.1 404 Not Found"
	;;
    esac

    new "get startup 42"
    expectpart "$(curl -u guest:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "$status" "$ret"

    #----------- Then edit
    case "$ret2" in
	0) ret=''
	   status="HTTP/1.1 204 No Content"
	;;
	1) ret='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'
	   status="HTTP/1.1 403 Forbidden"
	;;
    esac
    new "edit new 99"
    expectpart "$(curl -u guest:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"nacm-example:x": 99}' $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "$status" "$ret"

    #----------- Then second get
    case "$ret3" in
	0) ret='{"nacm-example:x":99}'
	   status="HTTP/1.1 200 OK"
	;;
	1) ret='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'
	   status="HTTP/1.1 403 Forbidden"
        ;;
	2) ret='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'
	   status="HTTP/1.1 404 Not Found"
	   ;;
	3) ret='{"nacm-example:x":42}'
	   status="HTTP/1.1 200 OK"
	   ;;
    esac

    new "get 99"
    expectpart "$(curl -u guest:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "$status" "$ret"
    
    sleep $DEMSLEEP

    if [ $RC -ne 0 ]; then     # Bring your own restconf
	new "Kill restconf daemon"
	stop_restconf
    fi
    
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
# Outer loop either starts from startup or inits config via restconf POST
for db in startup init; do
    new "1. nacm enabled and all defaults permit"
    testrun true permit permit permit 0 0 0 $db

    new "2. nacm disabled and all defaults permit"
    testrun false permit permit permit 0 0 0 $db

    new "3. nacm disabled and all defaults deny"
    testrun false deny deny deny 0 0 0 $db

    new "4. nacm enabled, all defaults deny (expect fail)"
    testrun true deny deny deny 1 1 1 $db

    new "5. nacm enabled, exec default deny - read permit (expect fail)"
    testrun true permit deny deny 1 1 1 $db

    new "6. nacm enabled, exec default deny - write permit (expect fail)"
    testrun true deny permit deny 1 1 1 $db

    new "7. nacm enabled, exec default deny read/write permit (expect fail)"
    testrun true permit permit deny 1 1 1 $db

    new "8. nacm enabled, exec default permit, all others deny (expect fail)"
    testrun true deny deny permit 2 1 2 $db

    new "9. nacm enabled, exec default permit, read permit (expect fail)"
    testrun true permit deny permit 0 1 3 $db  # This is yang default

    new "10. nacm enabled, exec default permit, write permit (expect fail)"
    testrun true deny permit permit 2 0 2 $db

done

endtest

rm -rf $dir

# Set by restconf_config
unset RESTCONFIG

# unset conditional parameters 
unset format
