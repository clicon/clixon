#!/usr/bin/env bash
# Test for RFC6022 YANG Module for NETCONF Monitoring
# See eg Examples:
# 4.1.  Retrieving Schema List via <get> Operation
# 4.2.  Retrieving Schema Instances
# Also: loop over all installed yang files and compare with get-schema

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example@2022-01-01.yang
fyangsub=$dir/clixon-sub@2022-01-01.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${dir}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_NETCONF_MONITORING>true</CLICON_NETCONF_MONITORING>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  include clixon-sub;
  revision 2022-01-01;
}
EOF

cat <<EOF > $fyangsub
submodule clixon-sub{
  yang-version 1.1;
  belongs-to clixon-example {
      prefix ex;
  }
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
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get/></rpc>" "<rpc-reply $DEFAULTNS><data><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability><capability>urn:ietf:params:netconf:base:1.1</capability>.*<capability>urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring</capability>.*</capabilities><datastores><datastore><name>candidate</name></datastore><datastore><name>running</name></datastore></datastores><schemas>.*</schemas><sessions>.*</sessions><statistics>.*</statistics></netconf-state></data></rpc-reply>"

# send multiple frames using locks for more interesting datastore stat
rpc=$(chunked_framing "<rpc $DEFAULTNS><lock><target><candidate/></target></lock></rpc>")
rpc="${rpc}
$(chunked_framing "<rpc $DEFAULTNS><get><filter type=\"subtree\"><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><datastores><datastore><name>candidate</name></datastore></datastores></netconf-state></filter></get></rpc>")"

new "Get databases with lock"
ret=$($clixon_netconf -q -f $cfg <<EOF 
$DEFAULTHELLO$rpc
EOF
   )
r=$? 
if [ $r -ne 0 ]; then
    err "0" "$r"
fi
for expect in "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" "<rpc-reply $DEFAULTNS><data><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><datastores><datastore><name>candidate</name><locks><global-lock><locked-by-session>[0-9]+</locked-by-session><locked-time>202.*Z</locked-time></global-lock></locks></datastore></datastores></netconf-state></data></rpc-reply"; do
    new "expect:$expect"
    match=`echo $ret | grep --null -Eo "$expect"`
    if [ -z "$match" ]; then
        err "$expect" "$ret"
    fi
done

# 4.1.  Retrieving Schema List via <get> Operation
# match bith module and sub-module
# 2.1.3
new "Retrieving Schema List via <get> Operation"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><schemas/></netconf-state></filter></get></rpc>" "<rpc-reply $DEFAULTNS><data><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><schemas><schema><identifier>clixon-example</identifier><version>2022-01-01</version><format>yang</format><namespace>urn:example:clixon</namespace><location>NETCONF</location></schema>.*<schema><identifier>clixon-sub</identifier><version>2022-01-01</version><format>yang</format><namespace>urn:example:clixon</namespace><location>NETCONF</location></schema><schema>.*</schemas></netconf-state></data></rpc-reply>"

# Session 2.1.4
new "Retrieve Session"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><sessions/></netconf-state></filter></get></rpc>" "<rpc-reply $DEFAULTNS><data><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><sessions><session><session-id>[1-9][0-9]*</session-id><transport xmlns:cl=\"http://clicon.org/lib\">cl:netconf</transport><username>.*</username><login-time>.*</login-time><in-rpcs>[0-9][0-9]*</in-rpcs><in-bad-rpcs>[0-9][0-9]*</in-bad-rpcs><out-rpc-errors>[0-9][0-9]*</out-rpc-errors><out-notifications>[0-9][0-9]*</out-notifications></session>.*</sessions></netconf-state></data></rpc-reply>"

# Statistics 2.1.5
new "Retrieve Statistics"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><statistics/></netconf-state></filter></get></rpc>" "<rpc-reply $DEFAULTNS><data><netconf-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\"><statistics><netconf-start-time>20[0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*Z</netconf-start-time><in-bad-hellos>[0-9]\+</in-bad-hellos><in-sessions>[1-9][0-9]*</in-sessions><dropped-sessions>[0-9]\+</dropped-sessions><in-rpcs>[1-9][0-9]*</in-rpcs><in-bad-rpcs>[0-9]\+</in-bad-rpcs><out-rpc-errors>[0-9]\+</out-rpc-errors><out-notifications>[0-9]\+</out-notifications></statistics></netconf-state></data></rpc-reply>"

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

# for some reason valgrind tests fail below?
if [ ${valgrindtest} -eq 0 ]; then # Error dont cleanup mem OK

# XXX there may be inconsistent YANGs in this dir
YANGDIR=$YANG_INSTALLDIR

if [ $BE -ne 0 ]; then
    new "start backend -s init -f $cfg -o CLICON_YANG_MAIN_DIR=$YANGDIR -o CLICON_YANG_MAIN_FILE=$fyang"
    start_backend -s init -f $cfg  -o CLICON_YANG_MAIN_DIR=$YANGDIR
fi
new "wait backend"
wait_backend

new "Loop over all yangs in $YANGDIR"
for f in ${YANGDIR}/*.yang; do
    b=$(basename $f)
    id=$(echo "$b" | sed 's/.yang//' | sed 's/@.*//')
    version=$(echo "$b" | sed 's/.yang//' | sed 's/.*@//')
    $clixon_netconf -qf $cfg <<EOF > $dir/ex.yang
$HELLONO11
<rpc $DEFAULTNS>
   <get-schema xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring">
      <identifier>$id</identifier>
      <version>$version</version>
      <format>yang</format>
   </get-schema>
</rpc>]]>]]>
EOF
    grep "<rpc-error>" $dir/ex.yang > /dev/null
    if [ $? -eq 0 ]; then
        continue
    fi
    # Mask netconf header and footer
    sed -i -e "s/<rpc-reply $DEFAULTNS><data xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-monitoring\">//" $dir/ex.yang
    sed -i -e 's/<\/data><\/rpc-reply>]]>]]>//' $dir/ex.yang
    # Decode XML
    sed -i -e 's/&gt;/>/g' $dir/ex.yang
    sed -i -e 's/&lt;/</g' $dir/ex.yang
    sed -i -e 's/\&amp;/\&/g' $dir/ex.yang
    new "get-schema check yang $b"
    diff $dir/ex.yang $f
    if [ $? -ne 0 ]; then
        err1 "get-schema $f is different from original"
        continue
    fi
done
fi # valgrind

rm -rf $dir

new "endtest"
endtest
