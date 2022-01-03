#!/usr/bin/env bash
# Authentication and authorization and IETF NACM
# See RFC 8341 A.2
# But replaced ietf-netconf-monitoring with *
# Note:
#  1. credenials check set to none since USER poses as different users.
#  2. CLICON_NACM_DISABLE_ON_EMPTY: start with empty config and add nacm config

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config user false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang
module nacm-example{
  yang-version 1.1;
  namespace "urn:example:nacm";
  prefix nex;
  import ietf-netconf-acm {
	prefix nacm;
  }
  leaf x{
    type int32;
    description "something to edit";
  }
}
EOF

# The groups are slightly modified from RFC8341 A.1
# The rule-list is from A.2
RULES=$(cat <<EOF
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>false</enable-nacm>
     <read-default>permit</read-default>
     <write-default>deny</write-default>
     <exec-default>deny</exec-default>

     $NGROUPS

     <rule-list>
       <name>guest-acl</name>
       <group>guest</group>
       <rule>
         <name>deny-ncm</name>
         <module-name>*</module-name>
         <access-operations>*</access-operations>
         <action>deny</action>
         <comment>
             Do not allow guests any access to the NETCONF
             monitoring information.
         </comment>
       </rule>
     </rule-list>
     <rule-list>
       <name>limited-acl</name>
       <group>limited</group>
       <rule>
         <name>permit-get</name>
         <rpc-name>get</rpc-name>
         <module-name>*</module-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
         <comment>
             Allow get 
         </comment>
       </rule>
       <rule>
         <name>permit-get-config</name>
         <rpc-name>get-config</rpc-name>
         <module-name>*</module-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
         <comment>
             Allow get-config
         </comment>
       </rule>
     </rule-list>

     $NADMIN

   </nacm>
   <x xmlns="urn:example:nacm">0</x>
EOF
)

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

new "waiting"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

new "auth get"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 404" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

# explicitly disable nacm (regression on netgate bug)
new "disable nacm"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-netconf-acm:enable-nacm": false}' $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 "HTTP/$HVER 201"

new "auth set authentication config"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "commit it"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "auth get (no user: access denied)"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 401" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"access-denied","error-severity":"error","error-message":"The requested URL was unauthorized"}}}'

new "auth get (wrong passwd: access denied)"
expectpart "$(curl -u andy:foo $CURLOPTS -X GET $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 401" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"access-denied","error-severity":"error","error-message":"The requested URL was unauthorized"}}}'

new "auth get (access)"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 200" '{"nacm-example:x":0}'

#----------------Enable NACM

new "enable nacm"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-netconf-acm:enable-nacm": true}' $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 "HTTP/$HVER 204"

new "admin get nacm"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 200" '{"nacm-example:x":0}'

new "limited get nacm"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 200" '{"nacm-example:x":0}'

new "guest get nacm"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'

new "admin edit nacm"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"nacm-example:x":1}' $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 204"

new "limited edit nacm"
expectpart "$(curl -u wilma:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"nacm-example:x": 2}' $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "guest edit nacm"
expectpart "$(curl -u guest:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"nacm-example:x": 3}' $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'

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

# Set by restconf_config
unset RESTCONFIG

rm -rf $dir

new "endtest"
endtest
