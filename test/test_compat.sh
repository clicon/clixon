#!/bin/bash
# Test of backward compatibility
# 1) Load <3.9 startup/running/extra files without namespaces - ensure it returns namespaces
#

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_startup.xml

# Use yang in example

cat <<EOF > $cfg
<config>
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
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_CLI_LINESCROLLING>0</CLICON_CLI_LINESCROLLING>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
</config>

EOF


run(){
    mode=$1
    expect=$2

    dbdir=$dir/db
    cat <<EOF > $dbdir
<config>
   <interfaces>
      <interface>
         <name>run</name>
         <type>ex:eth</type>
      </interface>
    </interfaces>
</config>
EOF
    sudo mv $dbdir /usr/local/var/$APPNAME/running_db

    cat <<EOF > $dbdir
<config>
   <interfaces>
      <interface>
         <name>startup</name>
         <type>ex:eth</type>
      </interface>
    </interfaces>
</config>
EOF
    sudo mv $dbdir /usr/local/var/$APPNAME/startup_db

    cat <<EOF > $dir/config
<config>
   <interfaces>
      <interface>
         <name>extra</name>
         <type>ex:eth</type>
      </interface>
    </interfaces>
</config>
EOF

    new "test params: -f $cfg -s $mode -c $dir/config"

    if [ $BE -ne 0 ]; then
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
 	    err
	fi
    
	new "start backend  -f $cfg -s $mode -c $dir/config"
	sudo $clixon_backend -f $cfg -s $mode -c $dir/config
	if [ $? -ne 0 ]; then
	    err
	fi
    fi

    new "Check $mode"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' "^<rpc-reply>$expect</rpc-reply>]]>]]>$"

    if [ $BE -eq 0 ]; then
	exit # BE
    fi

    new "Kill backend"
    # Check if premature kill
    pid=`pgrep -u root -f clixon_backend`
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
	err "kill backend"
    fi

} # run 

run running '<data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>extra</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>lo</name><type>ex:loopback</type><enabled>true</enabled></interface><interface><name>run</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data>'
run startup '<data><interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>extra</name><type>ex:eth</type><enabled>true</enabled></interface><interface><name>lo</name><type>ex:loopback</type><enabled>true</enabled></interface><interface><name>startup</name><type>ex:eth</type><enabled>true</enabled></interface></interfaces></data>'

rm -rf $dir
