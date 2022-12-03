#!/usr/bin/env bash
# Test for RFC6022 YANG Module for NETCONF Monitoring
# See eg Examples:
# 4.1.  Retrieving Schema List via <get> Operation
# 4.2.  Retrieving Schema Instances

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example@2022-01-01.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
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
  <CLICON_NETCONF_MONITORING>true</CLICON_NETCONF_MONITORING>
</clixon-config>
EOF

cat <<EOF > $fyang
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

new "Retrieving all state via <get> operation"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get/></rpc>" "<rpc-reply $DEFAULTNS><data><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:base:1.1</capability>.*<capability>urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring</capability>.*</capabilities><schemas>.*</schemas></netconf-state></data></rpc-reply>"

# 4.1.  Retrieving Schema List via <get> Operation
new "Retrieving Schema List via <get> Operation"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><schemas/></netconf-state></filter></get></rpc>" "<rpc-reply $DEFAULTNS><data><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><schemas><schema><identifier>clixon-example</identifier><version>2022-01-01</version><format>yang</format><namespace>urn:example:clixon</namespace><location>NETCONF</location></schema>.*</schemas></netconf-state></data></rpc-reply>"

# 4.2.  Retrieving Schema Instances 
# From 2b. bar, version 2008-06-1 in YANG format, via get-schema
new "Retrieving clixon-example schema instance using id, version, format"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><identifier>clixon-example</identifier><version>2022-01-01</version><format>yang</format></get-schema></rpc>" "<rpc-reply $DEFAULTNS><data xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\">module clixon-example{"

new "Retrieving clixon-example schema instance using id, version only"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><identifier>clixon-example</identifier><version>2022-01-01</version></get-schema></rpc>" "<rpc-reply $DEFAULTNS><data xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\">module clixon-example{"

new "Retrieving clixon-example schema instance using id only"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><identifier>clixon-example</identifier></get-schema></rpc>" "<rpc-reply $DEFAULTNS><data xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\">module clixon-example{"

new "Retrieving ietf-inet-types schema"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><identifier>ietf-inet-types</identifier></get-schema></rpc>" "<rpc-reply $DEFAULTNS><data xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\">module ietf-inet-types {"

# Negative tests
new "get-schema: no id"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"></get-schema></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>missing-element</error-tag><error-info><bad-element>identifier</bad-element></error-info><error-severity>error</error-severity><error-message>Mandatory variable of get-schema in module ietf-netconf-monitoring</error-message></rpc-error></rpc-reply>"

new "get-schema: non-existing schema"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><identifier>not-found</identifier></get-schema></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>No schema matching: not-found</error-message></rpc-error></rpc-reply>"

new "get-schema: non-existing format"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><identifier>clixon-example</identifier><version>2022-01-01</version><format>xsd</format></get-schema></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>Format not supported: xsd</error-message></rpc-error></rpc-reply>"

new "get-schema: non-existing date"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><identifier>clixon-example</identifier><version>2013-01-01</version><format>yang</format></get-schema></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>No schema matching: clixon-example@2013-01-01</error-message></rpc-error></rpc-reply>"

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
