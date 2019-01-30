#!/bin/bash
# Authentication and authorization and IETF NACM
# NACM module rules
# A module rule has the "module-name" leaf set but no nodes from the
# "rule-type" choice set.
# @see test_nacm.sh is slightly modified - this follows the RFC more closely
# See RFC 8341 A.1 and A.2
# Note: use clixon-example instead of ietf-netconf-monitoring since the latter is
# Tests for 
# deny-ncm:  This rule prevents the "guest" group from reading any
#     monitoring information in the "clixon-example" YANG
#     module.
# permit-ncm:  This rule allows the "limited" group to read the
#     "clixon-example" YANG module.
# permit-exec:  This rule allows the "limited" group to invoke any
#     protocol operation supported by the server.
# permit-all:  This rule allows the "admin" group complete access to
#     all content in the server.  No subsequent rule will match for the
#     "admin" group because of this module rule

APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
</config>
EOF

cat <<EOF > $fyang
module nacm-example{
  yang-version 1.1;
  namespace "urn:example:nacm";
  prefix nacm;
  import clixon-example {
	prefix ex;
  }
  import ietf-netconf-acm {
	prefix nacm;
  }
  leaf x{
    type int32;
    description "something to edit";
  }
}
EOF

# The groups are slightly modified from RFC8341 A.1 ($USER added in admin group)
# The rule-list is from A.2 
RULES=$(cat <<EOF
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>false</enable-nacm>
     <read-default>deny</read-default>
     <write-default>deny</write-default>
     <exec-default>deny</exec-default>

     $NGROUPS

     <rule-list>
       <name>guest-acl</name>
       <group>guest</group>
       <rule>
         <name>permit-get</name>
         <module-name>ietf-netconf</module-name>
         <rpc-name>*</rpc-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
         <comment>
             Allow invocation of get rpc
         </comment>
       </rule>
       <rule>
         <name>permit-read</name>
         <module-name>clixon-example</module-name>
         <access-operations>read</access-operations>
         <action>permit</action>
         <comment>
             Do not allow guests any access to the NETCONF
             monitoring information.
         </comment>
       </rule>
       <rule>
         <name>deny-write</name>
         <module-name>clixon-example</module-name>
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
         <name>permit-ncm</name>
         <module-name>clixon-example</module-name>
         <access-operations>read create update delete</access-operations>
         <action>permit</action>
         <comment>
             Allow write access to the NETCONF monitoring information.
         </comment>
       </rule>
       <rule>
         <name>permit-exec</name>
         <module-name>*</module-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
         <comment>
             Allow invocation of the supported server operations.
         </comment>
       </rule>
     </rule-list>

     $NADMIN

   </nacm>
   <x xmlns="urn:example:nacm">42</x>
   <translate xmlns="urn:example:clixon"><k>key42</k><value>val42</value></translate>
   <translate xmlns="urn:example:clixon"><k>key43</k><value>val43</value></translate>
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
    sudo $clixon_backend -s init -f $cfg -D $DBG
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

sleep 1
new "start restconf daemon (-a is enable basic authentication)"
sudo su -c "$clixon_restconf -f $cfg -D $DBG -- -a" -s /bin/sh www-data &

sleep $RCWAIT

new "auth set authentication config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "commit it"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "enable nacm"
expecteq "$(curl -u andy:bar -sS -X PUT -d '{"enable-nacm": true}' http://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" ""

#--------------- nacm enabled
#----WRITE access
#user:admin
new2 "admin read element ok"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/clixon-example:translate=key42/value)" '{"clixon-example:value": "val42"}
'

new "admin write element ok"
expecteq "$(curl -u andy:bar -sS -X PUT http://localhost/restconf/data/clixon-example:translate=key42/value -d '{"clixon-example:value": "val99"}')"

#user:limit
new2 "limit read element ok"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data/clixon-example:translate=key42/value)" '{"clixon-example:value": "val99"}
'

new "limit write element ok"
expecteq "$(curl -u wilma:bar -sS -X PUT http://localhost/restconf/data/clixon-example:translate=key42/value -d '{"clixon-example:value": "val55"}')"

#user:guest
new2 "guest read element ok"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/clixon-example:translate=key42/value)" '{"clixon-example:value": "val55"}
'

new2 "guest write element ok"
expecteq "$(curl -u guest:bar -sS -X PUT http://localhost/restconf/data/clixon-example:translate=key42/value -d '{"clixon-example:value": "val99"}')" '{"ietf-restconf:errors" : {"error": {"error-type": "application","error-tag": "access-denied","error-severity": "error","error-message": "access denied"}}}'

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
