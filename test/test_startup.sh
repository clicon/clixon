#!/bin/bash
# Startup test: Start clicon daemon in the (four) different startup modes
# (init, none, running, or startup)
# The dbs and files are setup as follows:
# - The example reset_state callback adds "lo" interface
# - An extra xml configuration file starts with an "extra" interface
# - running db starts with a "run" interface
# - startup db starts with a "start" interface
# There is also an "invalid" XML and a "broken" XML
# There are two steps, first run through everything OK
# Then try with invalid and broken XML and ensure the backend quits and all is untouched

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

APPNAME=example

cfg=$dir/conf_startup.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>clixon-example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
</clixon-config>

EOF

# Create running-db containin the interface "run" OK
runvar='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>run</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>'

# Create startup-db containing the interface "startup" OK
startvar='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>startup</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>'

# extra OK
extravar='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>extra</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>'

# invalid (contains <not-defined/>), but OK XML syntax
invalidvar='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><not-defined/><name>invalid</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>'

# Broken XML (contains </nmae>)
brokenvar='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>broken</nmae><type>ex:eth</type><enabled>true</enabled></interface></interfaces>'

# Create a pre-set running, startup and (extra) config.
# The configs are identified by an interface called run, startup, extra.
# Depending on startup mode (init, none, running, or startup)
# expect different output of an initial get-config of running
testrun(){
    mode=$1
    rdb=$2    # running db at start
    sdb=$3    # startup db at start
    edb=$4    # extradb at start
    exprun=$5 # expected running_db after startup

    sudo rm -f  $dir/*_db
    echo "<config>$rdb</config>" > $dir/running_db
    echo "<config>$sdb</config>" > $dir/startup_db
    echo "<config>$edb</config>" > $dir/extra_db

    if [ $BE -ne 0 ]; then     # Bring your own backend
	# kill old backend (if any)
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
        new "start backend -f $cfg -s $mode -c $dir/extra_db"
	start_backend -s $mode -f $cfg -c $dir/extra_db

	new "waiting"
	wait_backend
    else
	new "Restart backend as eg follows: -Ff $cfg -s $mode -c $dir/extra_db # $BETIMEOUT s"
	sleep $BETIMEOUT
    fi
    new "Startup test for $mode mode, check running"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' "^<rpc-reply>$exprun</rpc-reply>]]>]]>$"

    new "Startup test for $mode mode, check candidate"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' "^<rpc-reply>$exprun</rpc-reply>]]>]]>$"

    new "Startup test for $mode mode, check startup is untouched"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><startup/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$sdb</data></rpc-reply>]]>]]>$"
    
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u $BUSER -f clixon_backend)
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
} # testrun


# The backend should fail with 255 and all db:s should be unaffected
testfail(){
    mode=$1
    rdb=$2    # running db at start
    sdb=$3    # startup db at start
    edb=$4    # extradb at start

    sudo rm -f  $dir/*_db

    echo "<config>$rdb</config>" > $dir/running_db
    echo "<config>$sdb</config>" > $dir/startup_db
    echo "<config>$edb</config>" > $dir/extra_db

    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -f $cfg -s $mode -c $dir/extra_db"
    ret=$(start_backend -1 -s $mode -f $cfg -c $dir/extra_db 2> /dev/null)
    r=$?
    if [ $r -ne 255 ]; then
	err "Unexpected retval" $r
    fi
    # permission kludges
    sudo chmod 666 $dir/running_db
    sudo chmod 666 $dir/startup_db
    new "Checking running unchanged"
    ret=$(diff $dir/running_db <(echo "<config>$rdb</config>"))
    if [ $? -ne 0 ]; then
	err "<config>$rdb</config>" "$ret"
    fi	
    new "Checking startup unchanged"
    ret=$(diff $dir/startup_db <(echo "<config>$sdb</config>"))
    if [ $? -ne 0 ]; then
	err "<config>$sdb</config>" "$ret"
    fi

    new "Checking extra unchanged"
    ret=$(diff $dir/extra_db <(echo "<config>$edb</config>"))
    if [ $? -ne 0 ]; then
	err "<config>$edb</config>" "$ret"
    fi
}

# 1. Try different modes on OK running/startup/extra
# Init mode: delete running and reload from scratch (just extra)
testrun init "$runvar" "$startvar" "$extravar" "<data>$extravar</data>" 

# None mode: do nothing, running remains
testrun none  "$runvar" "$startvar" "$extravar" "<data>$runvar</data>"

# Running mode: keep running but load also extra
testrun running "$runvar" "$startvar" "$extravar" '<data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>extra</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>run</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data>'

# Startup mode: scratch running, load startup with extra on top
testrun startup "$runvar" "$startvar" "$extravar" '<data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>extra</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>startup</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data>' 

# 2. Try different modes on Invalid running/startup/extra WITHOUT failsafe
# ensure all db:s are unchanged after failure.

# Valgrind backend tests make no sense in backend crash tests
if [ $valgrindtest -ne 2 ]; then
    new "Test invalid running in running mode"
    testfail running "$invalidvar" "$startvar" "$extravar"

    new "Run invalid startup in startup mode"
    testfail startup "$runvar" "$invalidvar" "$extravar"

    new "Test broken running in running mode"
    testfail running "$brokenvar" "$startvar" "$extravar"

    new "Run broken startup in startup mode"
    testfail startup "$runvar" "$brokenvar" "$extravar"
fi

rm -rf $dir
