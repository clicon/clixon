#!/bin/bash
# Startup test: Start clicon daemon in the (four) different startup modes
# and the dbs and files are setup as follows:
# - The example reset_state callback adds "lo" interface
# - An extra xml configuration file starts with an "extra" interface
# - running db starts with a "run" interface
# - startup db starts with a "start" interface

# include err() and new() functions
. ./lib.sh
cfg=/tmp/conf_startup.xml

# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
clixon_netconf=clixon_netconf
clixon_cli=clixon_cli

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/routing/yang</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLI_MODE>routing</CLICON_CLI_MODE>
  <CLICON_BACKEND_DIR>/usr/local/lib/routing/backend</CLICON_BACKEND_DIR>
  <CLICON_NETCONF_DIR>/usr/local/lib/routing/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/routing/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/routing/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/routing/clispec</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/routing/routing.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/routing/routing.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/routing</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_XML_SORT>true</CLICON_XML_SORT>
</config>

EOF

run(){
    mode=$1
    expect=$2

    cat <<EOF > /tmp/db
<config>
   <interfaces>
      <interface>
         <name>run</name>
         <type>eth</type>
      </interface>
    </interfaces>
</config>
EOF
    sudo mv /tmp/db /usr/local/var/routing/running_db

    cat <<EOF > /tmp/db
<config>
   <interfaces>
      <interface>
         <name>startup</name>
         <type>eth</type>
      </interface>
    </interfaces>
</config>
EOF
    sudo mv /tmp/db /usr/local/var/routing/startup_db

    cat <<EOF > /tmp/config
<config>
   <interfaces>
      <interface>
         <name>extra</name>
         <type>eth</type>
      </interface>
    </interfaces>
</config>
EOF

    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend  -f $cfg -s $mode -c /tmp/config"
    sudo clixon_backend -f $cfg -s $mode -c /tmp/config
    if [ $? -ne 0 ]; then
	err
    fi

    new "Check $mode"
    expecteof "$clixon_netconf -qf $cfg" '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' "^<rpc-reply>$expect</rpc-reply>]]>]]>$"

    new "Kill backend"
    # Check if still alive
    pid=`pgrep clixon_backend`
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err "kill backend"
    fi
}

run init    '<data/>'
run none    '<data><interfaces><interface><name>run</name><type>eth</type><enabled>true</enabled></interface></interfaces></data>'
run running '<data><interfaces><interface><name>extra</name><type>eth</type><enabled>true</enabled></interface><interface><name>lo</name><type>local</type><enabled>true</enabled></interface><interface><name>run</name><type>eth</type><enabled>true</enabled></interface></interfaces></data>'
run startup '<data><interfaces><interface><name>extra</name><type>eth</type><enabled>true</enabled></interface><interface><name>lo</name><type>local</type><enabled>true</enabled></interface><interface><name>startup</name><type>eth</type><enabled>true</enabled></interface></interfaces></data>'

