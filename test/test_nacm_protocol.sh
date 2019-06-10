#!/bin/bash
# Authentication and authorization and IETF NACM
# NACM protocol operation rules
# @see RFC 8341 A.1 and A.3 (and permit-all from A.2)
# Tests for three protocol operation rules (all apply to module ietf-netconf)
# deny-kill-session:  This rule prevents the "limited" group or the
#     "guest" group from invoking the NETCONF <kill-session> protocol
#     operation.
# deny-delete-config:  This rule prevents the "limited" group or the
#     "guest" group from invoking the NETCONF <delete-config> protocol
#     operation.
# permit-edit-config:  This rule allows the "limited" group to invoke
#     the NETCONF <edit-config> protocol operation.  This rule will have
#     no real effect unless the "exec-default" leaf is set to "deny".
#
#  From RFC8040, I conclude that commit/discard should be done automatically
#  BY THE SYSTEM
#  Otherwise, if the device supports :candidate, all edits to
#  configuration nodes in {+restconf}/data are performed in the
#  candidate configuration datastore.  The candidate MUST be
#  automatically committed to running immediately after each successful
#  edit.
# Which means that restconf -X DELETE /data translates to edit-config + commit
# which is allowed.

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
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
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
}
EOF
# The groups are slightly modified from RFC8341 A.1
# The rule-list is from A.2
RULES=$(cat <<EOF
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>false</enable-nacm>
     <read-default>deny</read-default>
     <write-default>permit</write-default>
     <exec-default>deny</exec-default>

     $NGROUPS

     <rule-list>
       <name>guest-limited-acl</name>
       <group>limited</group>
       <group>guest</group>
       <rule>
         <name>deny-kill-session</name>
         <module-name>ietf-netconf</module-name>
         <rpc-name>kill-session</rpc-name>
         <access-operations>exec</access-operations>
         <action>deny</action>
         <comment>
           Do not allow the 'limited' group or the 'guest' group
           to kill another session.
         </comment>
       </rule>
       <rule>
         <name>deny-delete-config</name>
         <module-name>ietf-netconf</module-name>
         <rpc-name>delete-config</rpc-name>
         <access-operations>exec</access-operations>
         <action>deny</action>
         <comment>
           Do not allow the 'limited' group or the 'guest' group
           to delete any configurations.
         </comment>
       </rule>
     </rule-list>
     <rule-list>
       <name>limited-acl</name>
       <group>limited</group>
       <rule>
         <name>permit-edit-config</name>
         <module-name>ietf-netconf</module-name>
         <rpc-name>edit-config</rpc-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
         <comment>
           Allow the 'limited' group to edit the configuration.
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

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

sleep 1
new "start restconf daemon (-a is enable basic authentication)"
start_restconf -f $cfg -- -a

new "waiting"
sleep $RCWAIT

new "auth set authentication config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "commit it"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "enable nacm"
expecteq "$(curl -u andy:bar -sS -X PUT -d '{"ietf-netconf-acm:enable-nacm": true}' http://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 ""

#--------------- nacm enabled

new "admin get nacm"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/nacm-example:x)" 0 '{"nacm-example:x": 0}
'

# Rule 1: deny-kill-session
new "deny-kill-session: limited fail (netconf)"
expecteof "$clixon_netconf -qf $cfg -U wilma" 0 "<rpc><kill-session><session-id>44</session-id></kill-session></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>access denied</error-message></rpc-error></rpc-reply>]]>]]>$"

new "deny-kill-session: guest fail (netconf)"
expecteof "$clixon_netconf -qf $cfg -U guest" 0 "<rpc><kill-session><session-id>44</session-id></kill-session></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>access denied</error-message></rpc-error></rpc-reply>]]>]]>$"

new "deny-kill-session: admin ok (netconf)"
expecteof "$clixon_netconf -qf $cfg -U andy" 0 "<rpc><kill-session><session-id>44</session-id></kill-session></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Rule 2: deny-delete-config
new "deny-delete-config: limited fail (netconf)"
expecteof "$clixon_netconf -qf $cfg -U wilma" 0 "<rpc><delete-config><target><startup/></target></delete-config></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>access denied</error-message></rpc-error></rpc-reply>]]>]]>$"

new "deny-delete-config: guest fail (restconf)"
expecteq "$(curl -u guest:bar -sS -X DELETE http://localhost/restconf/data)" 0 '{"ietf-restconf:errors" : {"error": {"error-type": "application","error-tag": "access-denied","error-severity": "error","error-message": "default deny"}}}'

# In restconf delete-config is translated to edit-config which is permitted
new "deny-delete-config: limited fail (restconf) ok"
expecteq "$(curl -u wilma:bar -sS -X DELETE http://localhost/restconf/data)" 0 ''

new "admin get nacm (should be null)"
expecteq "$(curl -u andy:bar -sS -X GET http://localhost/restconf/data/nacm-example:x)" 0 'null
'

new "deny-delete-config: admin ok (restconf)"
expecteq "$(curl -u andy:bar -sS -X DELETE http://localhost/restconf/data)" 0 ''

# Here the whole config is gone so we need to start again
new "auth set authentication config (restart)"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "commit it"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "enable nacm"
expecteq "$(curl -u andy:bar -sS -X PUT -d '{"ietf-netconf-acm:enable-nacm": true}' http://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 ""

# Rule 3: permit-edit-config
new "permit-edit-config: limited ok restconf"
expecteq "$(curl -u wilma:bar -sS -X PUT -d '{"nacm-example:x": 2}' http://localhost/restconf/data/nacm-example:x)" 0 ''

new "permit-edit-config: guest fail restconf"
expecteq "$(curl -u guest:bar -sS -X PUT -d '{"nacm-example:x": 2}' http://localhost/restconf/data/nacm-example:x)" 0 '{"ietf-restconf:errors" : {"error": {"error-type": "application","error-tag": "access-denied","error-severity": "error","error-message": "default deny"}}}'

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
