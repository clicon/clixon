#!/bin/bash
# Authentication and authorization and IETF NACM
# NACM data node rule
# @see RFC 8341 A.1 and A.4 (and permit-all from A.2)
# Tests for:
# deny-nacm:  This rule denies the "guest" group any access to the
#     /nacm subtree.
# permit-acme-config:  This rule gives the "limited" group read-write
#    access to the acme <config-parameters>.
# permit-dummy-interface:  This rule gives the "limited" and "guest"
#     groups read-update access to the acme <interface> entry named
#     "dummy".  This entry cannot be created or deleted by these groups;
#     it can only be altered.
# permit-interface:  This rule gives the "admin" group read-write
#     access to all acme <interface> entries.

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
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
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
         <name>deny-nacm</name>
         <path xmlns:n="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
           /n:nacm
         </path>
         <access-operations>*</access-operations>
         <action>deny</action>
         <comment>
           Deny the 'guest' group any access to the /nacm data.
         </comment>
       </rule>
     </rule-list>

     <rule-list>
       <name>limited-acl</name>
       <group>limited</group>

       <rule>
         <name>permit-acme-config</name>
         <path xmlns:acme="http://example.com/ns/netconf">
           /acme:acme-netconf/acme:config-parameters
         </path>
         <access-operations>
           read create update delete
         </access-operations>
         <action>permit</action>
         <comment>
           Allow the 'limited' group complete access to the acme
           NETCONF configuration parameters.  Showing long form
           of 'access-operations' instead of shorthand.
         </comment>
       </rule>
     </rule-list>
     <rule-list>
       <name>guest-limited-acl</name>
       <group>guest</group>
       <group>limited</group>

       <rule>
         <name>permit-dummy-interface</name>
         <path xmlns:acme="http://example.com/ns/itf">
           /acme:interfaces/acme:interface[acme:name='dummy']
         </path>
         <access-operations>read update</access-operations>
         <action>permit</action>
         <comment>
           Allow the 'limited' and 'guest' groups read
           and update access to the dummy interface.
         </comment>
       </rule>
     </rule-list>
     <rule-list>
       <name>admin-acl</name>
       <group>admin</group>
       <rule>
         <name>permit-interface</name>
         <path xmlns:acme="http://example.com/ns/itf">
           /acme:interfaces/acme:interface
         </path>
         <access-operations>*</access-operations>
         <action>permit</action>
         <comment>
           Allow the 'admin' group full access to all acme interfaces.
         </comment>
       </rule>
     </rule-list>

     $NADMIN

   </nacm>
   <x xmlns="urn:example:clixon">0</x>
EOF
)

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err
fi

new "start backend -s init -f $cfg"
# start new backend
sudo $clixon_backend -s init -f $cfg
if [ $? -ne 0 ]; then
    err
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

new2 "auth get (wrong passwd: access denied)"
expecteq "$(curl -u andy:foo -sS -X GET http://localhost/restconf/data)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "The requested URL was unauthorized"}}}'

new2 "auth get (access)"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/example:x)" '{"example:x": 0}
'

#----------------Enable NACM

new "enable nacm"
expecteq "$(curl -u andy:bar -sS -X PUT -d '{"enable-nacm": true}' http://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" ""

new2 "admin get nacm"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/example:x)" '{"example:x": 0}
'

new2 "limited get nacm"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data/example:x)" '{"example:x": 0}
'

new2 "guest get nacm"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/example:x)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "The requested URL was unauthorized"}}}'

new "admin edit nacm"
expecteq "$(curl -u andy:bar -sS -X PUT -d '{"x": 1}' http://localhost/restconf/data/example:x)" ""

new2 "limited edit nacm"
expecteq "$(curl -u wilma:bar -sS -X PUT -d '{"x": 2}' http://localhost/restconf/data/example:x)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "default deny"}}}'

new2 "guest edit nacm"
expecteq "$(curl -u guest:bar -sS -X PUT -d '{"x": 3}' http://localhost/restconf/data/example:x)" '{"ietf-restconf:errors" : {"error": {"error-type": "protocol","error-tag": "access-denied","error-severity": "error","error-message": "The requested URL was unauthorized"}}}'

new "Kill restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

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
