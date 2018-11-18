#!/bin/bash
# Authentication and authorization and IETF NACM
# External NACM file
# See RFC 8341 A.2
# But replaced ietf-netconf-monitoring with *

APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang
fyangerr=$dir/err.yang
nacmfile=$dir/nacmfile

# Note filter out example_backend_nacm.so in CLICON_BACKEND_REGEXP below
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/example/yang</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_NACM_MODE>external</CLICON_NACM_MODE>
  <CLICON_NACM_FILE>$nacmfile</CLICON_NACM_FILE>
</config>
EOF

cat <<EOF > $fyang
module $APPNAME{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  container authentication {
	description "Example code for enabling www basic auth and some example 
                     users";
    leaf basic_auth{
	description "Basic user / password authentication as in HTTP basic auth";
	type boolean;
	default true;
    }
    list auth {
	description "user / password entries. Valid if basic_auth=true";
	key user;
	leaf user{
	    description "User name";
	    type string;
	}
	leaf password{
	    description "Password";
	    type string;
	}
      }
    }
  leaf x{
    type int32;
    description "something to edit";
  }
    container state {
       config false;
       description "state data for example application";
       leaf-list op {
          type string;
       }
    }
}
EOF

cat <<EOF > $nacmfile
   <nacm>
     <enable-nacm>true</enable-nacm>
     <read-default>deny</read-default>
     <write-default>deny</write-default>
     <exec-default>deny</exec-default>
     <groups>
       <group>
         <name>admin</name>
         <user-name>admin</user-name>
         <user-name>adm1</user-name>
       </group>
       <group>
         <name>limited</name>
         <user-name>wilma</user-name>
         <user-name>bam-bam</user-name>
       </group>
       <group>
         <name>guest</name>
         <user-name>guest</user-name>
         <user-name>guest@example.com</user-name>
       </group>
     </groups>
     <rule-list>
       <name>guest-acl</name>
       <group>guest</group>
       <rule>
         <name>deny-ncm</name>
         <module-name>*</module-name>
         <access-operations>*</access-operations>
         <action>deny</action>
         <comment>
             Do not allow guests any access to any information.
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
     <rule-list>
       <name>admin-acl</name>
       <group>admin</group>
       <rule>
         <name>permit-all</name>
         <module-name>*</module-name>
         <access-operations>*</access-operations>
         <action>permit</action>
         <comment>
             Allow the 'admin' group complete access to all operations and data.
         </comment>
       </rule>
     </rule-list>
   </nacm>
EOF

# kill old backend (if any)
new "kill old backend -zf $cfg -y $fyang"
sudo clixon_backend -zf $cfg -y $fyang
if [ $? -ne 0 ]; then
    err
fi
sleep 1
new "start backend -s init -f $cfg -y $fyang"
# start new backend
sudo $clixon_backend -s init -f $cfg -y $fyang 
if [ $? -ne 0 ]; then
    err
fi

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon (-a is enable http basic auth)"
sudo su -c "$clixon_restconf -f $cfg -y $fyang -- -a" -s /bin/sh www-data &

sleep $RCWAIT

new "restconf DELETE whole datastore"
expecteq "$(curl -u adm1:bar -sS -X DELETE http://localhost/restconf/data)" ""

new2 "auth get"
expecteq "$(curl -u adm1:bar -sS -X GET http://localhost/restconf/data/state)" '{"state": {"op": "42"}}
'

new "Set x to 0"
expecteq "$(curl -u adm1:bar -sS -X PUT -d '{"x": 0}' http://localhost/restconf/data/x)" ""

new2 "auth get (no user: access denied)"
expecteq "$(curl -sS -X GET -H \"Accept:\ application/yang-data+json\" http://localhost/restconf/data)" '{"ietf-restconf:errors" : {"error": {"error-tag": "access-denied","error-type": "protocol","error-severity": "error","error-message": "The requested URL was unauthorized"}}}'

new2 "auth get (wrong passwd: access denied)"
expecteq "$(curl -u adm1:foo -sS -X GET http://localhost/restconf/data)" '{"ietf-restconf:errors" : {"error": {"error-tag": "access-denied","error-type": "protocol","error-severity": "error","error-message": "The requested URL was unauthorized"}}}'

new2 "auth get (access)"
expecteq "$(curl -u adm1:bar -sS -X GET http://localhost/restconf/data/x)" '{"x": 0}
'

new2 "admin get nacm"
expecteq "$(curl -u adm1:bar -sS -X GET http://localhost/restconf/data/x)" '{"x": 0}
'

new2 "limited get nacm"
expecteq "$(curl -u wilma:bar -sS -X GET http://localhost/restconf/data/x)" '{"x": 0}
'

new2 "guest get nacm"
expecteq "$(curl -u guest:bar -sS -X GET http://localhost/restconf/data/x)" '{"ietf-restconf:errors" : {"error": {"error-tag": "access-denied","error-type": "protocol","error-severity": "error","error-message": "The requested URL was unauthorized"}}}'

new "admin edit nacm"
expecteq "$(curl -u adm1:bar -sS -X PUT -d '{"x": 1}' http://localhost/restconf/data/x)" ""

new2 "limited edit nacm"
expecteq "$(curl -u wilma:bar -sS -X PUT -d '{"x": 2}' http://localhost/restconf/data/x)" '{"ietf-restconf:errors" : {"error": {"error-tag": "access-denied","error-type": "protocol","error-severity": "error","error-message": "default deny"}}}'

new2 "guest edit nacm"
expecteq "$(curl -u guest:bar -sS -X PUT -d '{"x": 3}' http://localhost/restconf/data/x)" '{"ietf-restconf:errors" : {"error": {"error-tag": "access-denied","error-type": "protocol","error-severity": "error","error-message": "The requested URL was unauthorized"}}}'

new "cli show conf as admin"
expectfn "$clixon_cli -1 -U adm1 -l o -f $cfg -y $fyang show conf" 0 "^x 1;$"

new "cli show conf as limited"
expectfn "$clixon_cli -1 -U wilma -l o -f $cfg -y $fyang show conf" 0 "^x 1;$"

new "cli show conf as guest"
expectfn "$clixon_cli -1 -U guest -l o -f $cfg -y $fyang show conf" 255 "protocol access-denied"

new "cli rpc as admin"
expectfn "$clixon_cli -1 -U adm1 -l o -f $cfg -y $fyang rpc ipv4" 0 "<next-hop-list>2.3.4.5</next-hop-list>"

new "cli rpc as limited"
expectfn "$clixon_cli -1 -U wilma -l o -f $cfg -y $fyang rpc ipv4" 255 "protocol access-denied default deny"

new "cli rpc as guest"
expectfn "$clixon_cli -1 -U guest -l o -f $cfg -y $fyang rpc ipv4" 255 "protocol access-denied access denied"

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
