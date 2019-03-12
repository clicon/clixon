#!/bin/bash
# Startup test: Start clicon daemon in the (four) different startup modes
# (init, none, running, or startup)
# The dbs and files are setup as follows:
# - The example reset_state callback adds "lo" interface
# - An extra xml configuration file starts with an "extra" interface
# - running db starts with a "run" interface
# - startup db starts with a "start" interface

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_startup.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
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
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
</clixon-config>

EOF

# Create running-db containin the interface "run"
runvar='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>run</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>'

# Create startup-db containing the interface "startup"
startvar='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>startup</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>'

# extra
extravar='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>extra</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces>'

# Create a pre-set running, startup and (extra) config.
# The configs are identified by an interface called run, startup, extra.
# Depending on startup mode (init, none, running, or startup)
# expect different output of an initial get-config of running
testrun(){
    mode=$1
    exprun=$2 # expected running_db after startup

    sudo rm -f  $dir/*_db
    echo "<config>$runvar</config>" > $dir/running_db
    echo "<config>$startvar</config>" > $dir/startup_db
    echo "<config>$extravar</config>" > $dir/extra_db

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
	sleep $RCWAIT
    else
	new "Restart backend as eg follows: -Ff $cfg -s $mode -c $dir/extra_db # $BETIMEOUT s"
	sleep $BETIMEOUT
    fi
    new "Startup test for $mode mode, check running"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' "^<rpc-reply>$exprun</rpc-reply>]]>]]>$"

    new "Startup test for $mode mode, check candidate"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' "^<rpc-reply>$exprun</rpc-reply>]]>]]>$"

    new "Startup test for $mode mode, check startup is untouched"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><startup/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$startvar</data></rpc-reply>]]>]]>$"
    
    new "Kill backend"
    # Check if premature kill
    pid=`pgrep -u root -f clixon_backend`
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
} # testrun

# Init mode: delete running and reload from scratch (just extra)
testrun init "<data>$extravar</data>"

# None mode: do nothing, running remains
testrun none  "<data>$runvar</data>"

# Running mode: keep running but load also extra
testrun running '<data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>extra</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>run</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data>'

# Startup mode: scratch running, load startup with extra on top
testrun startup '<data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>extra</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>startup</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data>'

echo $dir
#rm -rf $dir
