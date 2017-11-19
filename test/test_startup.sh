#!/bin/bash
# Startup test: Start clicon daemon in the (four) different startup modes
# and the dbs and files are setup as follows:
# - The example reset_state callback adds "lo" interface
# - An extra xml configuration file starts with an "extra" interface
# - running db starts with a "run" interface
# - startup db starts with a "start" interface

# include err() and new() functions
. ./lib.sh

# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
clixon_netconf=clixon_netconf
clixon_cli=clixon_cli

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
    sudo clixon_backend -zf $clixon_cf 
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend"
    # start new backend
    sudo clixon_backend -f $clixon_cf -s $mode -c /tmp/config
    if [ $? -ne 0 ]; then
	err
    fi

    new "Check $mode"
    expecteof "$clixon_netconf -qf $clixon_cf" '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' "^<rpc-reply>$expect</rpc-reply>]]>]]>$"

    new "Kill backend"
    # Check if still alive
    pid=`pgrep clixon_backend`
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    sudo clixon_backend -zf $clixon_cf
    if [ $? -ne 0 ]; then
	err "kill backend"
    fi
}

run init    '<data/>'
run none    '<data><interfaces><interface><name>run</name><type>eth</type><enabled>true</enabled></interface></interfaces></data>'
run running '<data><interfaces><interface><name>run</name><type>eth</type><enabled>true</enabled></interface><interface><name>lo</name><type>local</type><enabled>true</enabled></interface><interface><name>extra</name><type>eth</type><enabled>true</enabled></interface></interfaces></data>'
run startup '<data><interfaces><interface><name>startup</name><type>eth</type><enabled>true</enabled></interface><interface><name>lo</name><type>local</type><enabled>true</enabled></interface><interface><name>extra</name><type>eth</type><enabled>true</enabled></interface></interfaces></data>'

