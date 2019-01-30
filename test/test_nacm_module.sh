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
         <name>permit-read</name>
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
         <access-operations>read</access-operations>
         <action>permit</action>
         <comment>
             Allow read access to the NETCONF monitoring information.
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

#----READ access
#user:admin
new2 "admin read ok"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/clixon-example:translate)" '{"clixon-example:translate": [{"k": "key42","value": "val42"},{ "k": "key43","value": "val43"}]}
'

new2 "admin read netconf ok"
expecteof "$clixon_netconf -U andy -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/translate"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><translate xmlns="urn:example:clixon"><k>key42</k><value>val42</value></translate><translate xmlns="urn:example:clixon"><k>key43</k><value>val43</value></translate></data></rpc-reply>]]>]]>$'

new2 "admin read element ok"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/clixon-example:translate=key42/value)" '{"clixon-example:value": "val42"}
'

new2 "admin read other module OK"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/nacm-example:x)" '{"nacm-example:x": 42}
'

new2 "admin read state OK"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/clixon-example:state)" '{"clixon-example:state": {"op": "42"}}
'

new "admin read top ok (all)"
ret=$(curl -u andy:bar -sS -X GET http://localhost/restconf/data)
expect='{"data": {"nacm-example:x": 42,"clixon-example:translate":'
match=`echo $ret | grep -EZo "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

#user:limit

new2 "limit read ok"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data/clixon-example:translate)" '{"clixon-example:translate": [{"k": "key42","value": "val42"},{ "k": "key43","value": "val43"}]}
'

new2 "limit read netconf ok"
expecteof "$clixon_netconf -U wilma -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/translate"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><translate xmlns="urn:example:clixon"><k>key42</k><value>val42</value></translate><translate xmlns="urn:example:clixon"><k>key43</k><value>val43</value></translate></data></rpc-reply>]]>]]>$'

new2 "limit read element ok"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data/clixon-example:translate=key42/value)" '{"clixon-example:value": "val42"}
'

new2 "limit read other module fail"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data/nacm-example:x)" 'null
'

new2 "limit read state OK"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data/clixon-example:state)" '{"clixon-example:state": {"op": "42"}}
'

new2 "limit read top ok (part)"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data)" '{"data": {"clixon-example:translate": [{"k": "key42","value": "val42"},{ "k": "key43","value": "val43"}],"clixon-example:state": {"op": "42"}}}
'

#user:guest

new2 "guest read fail"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/clixon-example:translate)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "default deny"}}}'

new2 "guest read netconf fail"
expecteof "$clixon_netconf -U guest -qf $cfg" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/translate"/></get-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>protocol</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>default deny</error-message></rpc-error></rpc-reply>]]>]]>$'

new2 "guest read element fail"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/clixon-example:translate=key42/value)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "default deny"}}}'

new2 "guest read other module fail"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/nacm-example:x)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "default deny"}}}'

new2 "guest read state fail"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/clixon-example:state)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "default deny"}}}'

new2 "guest read top ok (part)"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "default deny"}}}'

#------- RPC operation

new2 "admin rpc ok"
expecteq "$(curl -u andy:bar -s -X POST  -d '{"clixon-example:input":{"x":42}}' http://localhost/restconf/operations/clixon-example:example)" '{"clixon-example:output": {"x": "42","y": "42"}}
'

new "admin rpc netconf ok"
expecteof "$clixon_netconf -U andy -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><example xmlns="urn:example:clixon"><x>0</x></example></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><x xmlns="urn:example:clixon">0</x><y xmlns="urn:example:clixon">42</y></rpc-reply>]]>]]>$'

new2 "limit rpc ok"
expecteq "$(curl -u wilma:bar -s -X POST http://localhost/restconf/operations/clixon-example:example -d '{"clixon-example:input":{"x":42}}' )" '{"clixon-example:output": {"x": "42","y": "42"}}
'

new "limit rpc netconf ok"
expecteof "$clixon_netconf -U wilma -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><example xmlns="urn:example:clixon"><x>0</x></example></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><x xmlns="urn:example:clixon">0</x><y xmlns="urn:example:clixon">42</y></rpc-reply>]]>]]>$'

new2 "guest rpc fail"
expecteq "$(curl -u guest:bar -s -X POST http://localhost/restconf/operations/clixon-example:example -d '{"clixon-example:input":{"x":42}}' )" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "access denied"}}}'

new "guest rpc netconf fail"
expecteof "$clixon_netconf -U guest -qf $cfg" 0 '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><example xmlns="urn:example:clixon"><x>0</x></example></rpc>]]>]]>' '^<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><rpc-error><error-type>protocol</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>access denied</error-message></rpc-error></rpc-reply>]]>]]>$'

#------------------ Set read-default permit

new "admin set read-default permit"
expecteq "$(curl -u andy:bar -sS -X PUT -d '{"read-default": "permit"}' http://localhost/restconf/data/ietf-netconf-acm:nacm/read-default)" ""

new2 "limit read ok"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data/clixon-example:translate)" '{"clixon-example:translate": [{"k": "key42","value": "val42"},{ "k": "key43","value": "val43"}]}
'

new2 "limit read other module ok"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data/nacm-example:x)" '{"nacm-example:x": 42}
'

new2 "guest read state fail"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/clixon-example:state)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "default deny"}}}'


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
