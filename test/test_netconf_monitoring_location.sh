#!/usr/bin/env bash
# Test for RFC6022 YANG Module for NETCONF Monitoring
# Tests the location scheme by using the clixon http-data feature

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example@2022-01-01.yang

# Proper test setup
datapath=/data
wdir=$dir/www
        
RESTCONFIG=$(restconf_config none false $RCPROTO $enable)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_FEATURE>clixon-restconf:http-data</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_HTTP_DATA_PATH>$datapath</CLICON_HTTP_DATA_PATH>
  <CLICON_HTTP_DATA_ROOT>$wdir</CLICON_HTTP_DATA_ROOT>
  <CLICON_NETCONF_MONITORING>true</CLICON_NETCONF_MONITORING>
  <CLICON_NETCONF_MONITORING_LOCATION>$RCPROTO://localhost/www</CLICON_NETCONF_MONITORING_LOCATION>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $dir/clixon-example@2022-01-01.yang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  revision 2022-01-01;
}
EOF

# Same via HTTP
cat <<EOF > $dir/www/data/clixon-example@2022-01-01.yang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  revision 2022-01-01;
}
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf $RCPROTO

new "Retrieving Schema List via <get> Operation"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><schemas/></netconf-state></filter></get></rpc>" "<rpc-reply $DEFAULTNS><data><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><schemas><schema><identifier>clixon-example</identifier><version>2022-01-01</version><format>yang</format><namespace>urn:example:clixon</namespace><location>NETCONF</location><location>$RCPROTO://localhost/www/clixon-example@2022-01-01.yang</location></schema>.*</schemas></netconf-state></data></rpc-reply>"

# 4.2.  Retrieving Schema Instances 
# From 2b. bar, version 2008-06-1 in YANG format, via get-schema
new "Get clixon-example schema via http location"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: text/html' $RCPROTO://localhost/www/clixon-example@2022-01-01.yang)" 0 "HTTP/$HVER 404"

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
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

rm -rf $dir

new "endtest"
endtest
