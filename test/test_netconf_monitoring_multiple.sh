#!/usr/bin/env bash
# Test for RFC6022 YANG Module for NETCONF Monitoring for multiple schemas
# Clixon supports multiple schemas only in the case of specific upgrade scenarios
# The following is made to check multipel schemas:
# 1. Two revisions of clixon-example.yang in MAIN_DIR
# 2. MODSTATE and CHECKOLD is true and STARTUP enabled

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_UPGRADE_CHECKOLD>true</CLICON_XMLDB_UPGRADE_CHECKOLD>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <CLICON_NETCONF_MONITORING>true</CLICON_NETCONF_MONITORING>
</clixon-config>
EOF

# Double yang specs to get two revisions
cat <<EOF > $dir/clixon-example@2000-01-01.yang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  revision 2000-01-01;
}
EOF

cat <<EOF > $dir/clixon-example@2022-01-01.yang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  revision 2022-01-01;
}
EOF

# Just to get multi
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
  <yang-library xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
     <module-set>
        <name>default</name>
        <content-id>42</content-id>
        <module>
           <name>clixon-example</name>
           <revision>2000-01-01</revision>
           <namespace>urn:example:clixon</namespace>
        </module>
     </module-set>
  </yang-library>
</${DATASTORE_TOP}>
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

new "get-schema: multiple schemas, fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><identifier>clixon-example</identifier></get-schema></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-app-tag>data-not-unique</error-app-tag><error-severity>error</error-severity></rpc-error></rpc-reply>"

new "get-schema: multiple schemas 2000-01-01"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><identifier>clixon-example</identifier><version>2000-01-01</version></get-schema></rpc>" "<rpc-reply $DEFAULTNS><data xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\">module clixon-example{"

new "get-schema: multiple schemas 2022-01-01"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-schema xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><identifier>clixon-example</identifier><version>2022-01-01</version></get-schema></rpc>" "<rpc-reply $DEFAULTNS><data xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\">module clixon-example{"

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
