#!/bin/bash
# Authentication and authorization and IETF NACM
# NACM module rules
# A module rule has the "module-name" leaf set but no nodes from the
# "rule-type" choice set.
# @see test_nacm.sh is slightly modified - this follows the RFC more closely
# See RFC 8341 A.1 and A.2
# Note: use clixon-example instead of ietf-netconf-monitoring since the latter is
# A) Three tracks in the code for leaf/leaf-list, container/lists, and root
# B) Three operations: create, update, delete (write)
# C) Two access operations: permit, deny  (also default deny/permit)
# This gives 18 testcases
# Set group access:
# - Admin: permit: create, update, delete
# - Limit: permit: create, delete; deny: update
# - Guest: permit: update; deny: create delete
# ops\track:|  root  |  leaf  | list
#-----------+--------+--------+----------
# create    |  na    |  p/d   | p/d
# update    |  p/d   |  p/d   | p/d
# delete    |  p/d   |  p/d   | p/d

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
</clixon-config>
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
  list a{
    key k;
    leaf k{
      type string;
    }
    container b{
      leaf c{
        type string;
      }
    }
  }
}
EOF

# The groups are slightly modified from RFC8341 A.1 ($USER added in admin group)
# The rule-list is from A.2 
RULES=$(cat <<EOF
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>true</enable-nacm>
     <read-default>deny</read-default>
     <write-default>deny</write-default>
     <exec-default>permit</exec-default>

     $NGROUPS

     <rule-list>
       <name>limited-acl</name>
       <group>limited</group>
       <rule>
         <name>permit-create-delete</name>
         <module-name>nacm-example</module-name>
         <access-operations>read create delete</access-operations>
         <action>permit</action>
       </rule>
       <rule>
         <name>deny-update</name>
         <module-name>nacm-example</module-name>
         <access-operations>read update</access-operations>
         <action>deny</action>
       </rule>
     </rule-list>

     <rule-list>
       <name>guest-acl</name>
       <group>guest</group>
       <rule>
         <name>permit-update</name>
         <module-name>nacm-example</module-name>
         <access-operations>read update</access-operations>
         <action>permit</action>
       </rule>
       <rule>
         <name>deny-create-delete</name>
         <module-name>nacm-example</module-name>
         <access-operations>read create delete</access-operations>
         <action>deny</action>
       </rule>

     </rule-list>

     $NADMIN

   </nacm>
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

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon (-a is enable basic authentication)"
start_restconf -f $cfg -- -a

new "waiting"
wait_backend
wait_restconf

# Set nacm from scratch
nacm(){
    new "auth set authentication config"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config operation='replace'>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

    new "commit it"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

    new "enable nacm"
    expecteq "$(curl -u andy:bar -sS -X PUT -d '{"ietf-netconf-acm:enable-nacm": true}' http://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 ""
}

#--------------- enable nacm
nacm

# ops\track:|  root  |  leaf  | list
#-----------+--------+--------+----------
# create    |  n/a   | xp/dx  |  p/d
# update    |  p/d   | xp/dx  |  p/d
# delete    |  p/d   | xp/dx  |  p/d

# replace all, then must include NACM rules as well
MSG="<data>$RULES</data>"
new "update root list permit"
expecteq "$(curl -u andy:bar -sS -H 'Content-Type: application/yang-data+xml' -X PUT http://localhost/restconf/data -d "$MSG")" 0 ''

new "delete root list deny"
expecteq "$(curl -u wilma:bar -sS -X DELETE http://localhost/restconf/data)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "delete root permit"
expecteq "$(curl -u andy:bar -sS -X DELETE http://localhost/restconf/data)" 0 ''

#--------------- re-enable nacm
nacm

#----------leaf
new "create leaf deny"
expecteq "$(curl -u guest:bar -sS -H 'Content-Type: application/yang-data+xml' -X PUT http://localhost/restconf/data/nacm-example:x -d '<x xmlns="urn:example:nacm">42</x>')" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'

new "create leaf permit"
expecteq "$(curl -u wilma:bar -sS -H 'Content-Type: application/yang-data+xml' -X PUT http://localhost/restconf/data/nacm-example:x -d '<x xmlns="urn:example:nacm">42</x>')" 0 ''

new "update leaf deny"
expecteq "$(curl -u wilma:bar -sS -H 'Content-Type: application/yang-data+xml' -X PUT http://localhost/restconf/data/nacm-example:x -d '<x xmlns="urn:example:nacm">99</x>')" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'

new "update leaf permit"
expecteq "$(curl -u guest:bar -sS -H 'Content-Type: application/yang-data+xml' -X PUT http://localhost/restconf/data/nacm-example:x -d '<x xmlns="urn:example:nacm">99</x>')" 0 ''

new "read leaf check"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/nacm-example:x)" 0 '{"nacm-example:x":99}
'

new "delete leaf deny"
expecteq "$(curl -u guest:bar -sS -X DELETE http://localhost/restconf/data/nacm-example:x)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'

new "delete leaf permit"
expecteq "$(curl -u wilma:bar -sS -X DELETE http://localhost/restconf/data/nacm-example:x)" 0 ''

#-----  list/container
new "create list deny"
expecteq "$(curl -u guest:bar -sS -H 'Content-Type: application/yang-data+xml' -X PUT http://localhost/restconf/data/nacm-example:a=key42 -d '<a xmlns="urn:example:nacm"><k>key42</k><b><c>str</c></b></a>')" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'

new "create list permit"
expecteq "$(curl -u wilma:bar -sS -H 'Content-Type: application/yang-data+xml' -X PUT http://localhost/restconf/data/nacm-example:a=key42 -d '<a xmlns="urn:example:nacm"><k>key42</k><b><c>str</c></b></a>')" 0 ''

new "update list deny"
expecteq "$(curl -u wilma:bar -sS -H 'Content-Type: application/yang-data+xml' -X PUT http://localhost/restconf/data/nacm-example:a=key42 -d '<a xmlns="urn:example:nacm"><k>key42</k><b><c>update</c></b></a>')" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'

new "update list permit"
expecteq "$(curl -u guest:bar -sS -H 'Content-Type: application/yang-data+xml' -X PUT http://localhost/restconf/data/nacm-example:a=key42 -d '<a xmlns="urn:example:nacm"><k>key42</k><b><c>update</c></b></a>')" 0 ''

new "read list check"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/nacm-example:a)" 0 '{"nacm-example:a":[{"k":"key42","b":{"c":"update"}}]}
'

new "delete list deny"
expecteq "$(curl -u guest:bar -sS -X DELETE http://localhost/restconf/data/nacm-example:a=key42)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'

new "delete list permit"
expecteq "$(curl -u wilma:bar -sS -X DELETE http://localhost/restconf/data/nacm-example:a=key42)" 0 ''

#----- default deny (clixon-example limit and guest have default access)
new "default create list deny"
expecteq "$(curl -u wilma:bar -sS -X PUT http://localhost/restconf/data/clixon-example:translate=key42 -d '{"clixon-example:translate": [{"k":"key42","value":"val42"}]}')" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "create list permit"
expecteq "$(curl -u andy:bar -sS -X PUT http://localhost/restconf/data/clixon-example:translate=key42 -d '{"clixon-example:translate": [{"k":"key42","value":"val42"}]}')" 0 ''

new "default update list deny"
expecteq "$(curl -u wilma:bar -sS -X PUT http://localhost/restconf/data/clixon-example:translate=key42 -d '{"clixon-example:translate": [{"k":"key42","value":"val99"}]}')" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "default delete list deny"
expecteq "$(curl -u wilma:bar -sS -X DELETE http://localhost/restconf/data/clixon-example:translate=key42)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "Kill restconf daemon"
stop_restconf 

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
stop_backend -f $cfg

rm -rf $dir
