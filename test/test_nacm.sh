#!/bin/bash
# Authentication and authorization and IETF NACM
# See RFC 8341 A.2
# But replaced ietf-netconf-monitoring with *

APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang
fyangerr=$dir/err.yang

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
</config>
EOF

cat <<EOF > $fyang
module $APPNAME{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
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
   <nacm>
     <enable-nacm>false</enable-nacm>
     <read-default>deny</read-default>
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
   <x>0</x>
EOF
)

new "test params: -f $cfg -y $fyang"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg -y $fyang"
    sudo $clixon_backend -s init -f $cfg -y $fyang -D $DBG
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

sleep 1
new "start restconf daemon (-a is enable basic authentication)"
sudo su -c "$clixon_restconf -f $cfg -y $fyang -- -a" -s /bin/sh www-data &

sleep $RCWAIT

new "restconf DELETE whole datastore"
expecteq "$(curl -u andy:bar -sS -X DELETE http://localhost/restconf/data)" ""

new2 "auth get"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/x)" 'null
'

new "auth set authentication config"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "commit it"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new2 "auth get (no user: access denied)"
expecteq "$(curl -sS -X GET -H \"Accept:\ application/yang-data+json\" http://localhost/restconf/data)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "The requested URL was unauthorized"}}}'

new2 "auth get (wrong passwd: access denied)"
expecteq "$(curl -u andy:foo -sS -X GET http://localhost/restconf/data)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "The requested URL was unauthorized"}}}'

new2 "auth get (access)"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/x)" '{"x": 0}
'

#----------------Enable NACM

new "enable nacm"
expecteq "$(curl -u andy:bar -sS -X PUT -d '{"enable-nacm": true}' http://localhost/restconf/data/nacm/enable-nacm)" ""

new2 "admin get nacm"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/x)" '{"x": 0}
'

new2 "limited get nacm"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data/x)" '{"x": 0}
'

new2 "guest get nacm"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/x)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "access denied"}}}'

new "admin edit nacm"
expecteq "$(curl -u andy:bar -sS -X PUT -d '{"x": 1}' http://localhost/restconf/data/x)" ""

new2 "limited edit nacm"
expecteq "$(curl -u wilma:bar -sS -X PUT -d '{"x": 2}' http://localhost/restconf/data/x)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "default deny"}}}'

new2 "guest edit nacm"
expecteq "$(curl -u guest:bar -sS -X PUT -d '{"x": 3}' http://localhost/restconf/data/x)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "access denied"}}}'

new "Kill restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

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

rm -rf $dir
