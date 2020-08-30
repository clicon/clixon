#!/usr/bin/env bash
# Authentication and authorization and IETF NACM
# NACM data node rules
# See RFC 8341 A.4. Quote:
#
# Data node rules are used to control access to specific (config and
# non-config) data nodes within the NETCONF content provided by the
# server.
# This example shows four data node rules:
#
#  deny-nacm:  This rule denies the "guest" group any access to the
#     /nacm subtree.
#
#  permit-acme-config:  This rule gives the "limited" group read-write
#     access to the acme <config-parameters>.
#
#  permit-dummy-interface:  This rule gives the "limited" and "guest"
#     groups read-update access to the acme <interface> entry named
#     "dummy".  This entry cannot be created or deleted by these groups;
#     it can only be altered.
#
#  permit-interface:  This rule gives the "admin" group read-write
#     access to all acme <interface> entries.
#
# Test as follows:
# 1. limit can read /nacm
# 2. guest cannot read /nacm
# 3. limited can read and set /config-parameters
# 4. guest cannot set /config-parametesr
# 5. limit can read and update but not create or delete dummy interface
# 6. admin can POST dummy interface
# 7. guest|limit can read and PUT dummy interface
# 8. guest|limit cannot DELETE dummy interface
# 9. admin can DELETE dummy interface

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang
fyang2=$dir/itf.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
</clixon-config>
EOF

# There are two implicit modules defined by RFC 8341
# This is a try to define them
cat <<EOF > $fyang
module nacm-example{
  yang-version 1.1;
  namespace "http://example.com/ns/netconf";
  prefix ex;
  import ietf-netconf-acm {
	prefix nacm;
  } 
  import itf {
	prefix acme;
  }
  container acme-netconf{
    container config-parameters{
      list parameter{
        key name;
        leaf name{
          type string;
        }
        leaf value{
          type string;
        }
      }
    }
  }
}
EOF

cat <<EOF > $fyang2
module itf{
  yang-version 1.1;
  namespace "http://example.com/ns/itf";
  prefix acme;

  container interfaces{
    list interface{
      key name;
      leaf name{
        type string;
      }
      leaf value{
        type string;
      }
    }
  }
}
EOF

# The groups are slightly modified from RFC8341 A.1 ($USER added in admin group)
# The rule-list is from A.4
# Note read-default is set to permit to ensure that deny-nacm is meaningful
RULES=$(cat <<EOF
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>false</enable-nacm>
     <read-default>permit</read-default>
     <write-default>deny</write-default>
     <exec-default>permit</exec-default>

     $NGROUPS

     <rule-list>
       <name>guest-acl</name>
       <group>guest</group>
       <rule>
         <name>deny-nacm</name>
         <path xmlns:nacm="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
           /nacm:nacm
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
         <path xmlns:ex="http://example.com/ns/netconf">
           /ex:acme-netconf/acme:config-parameters
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

   </nacm>
EOF
)

CONFIG=$(cat <<EOF
   <acme-netconf xmlns="http://example.com/ns/netconf">
     <config-parameters>
       <parameter>
         <name>a</name>
         <value>72</value>
       </parameter>
     </config-parameters>
   </acme-netconf>
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

    new "start restconf daemon (-a is enable basic authentication)"
    start_restconf -f $cfg -- -a

    new "waiting"
    wait_restconf
fi

new "auth set authentication config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "set app config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config>$CONFIG</config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "commit it"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "enable nacm"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-netconf-acm:enable-nacm": true}' $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 "HTTP/1.1 204 No Content"

#--------------- nacm enabled

#user:admin,wilma,guest
new "admin can read /nacm"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 'HTTP/1.1 200 OK' '{"ietf-netconf-acm:enable-nacm":true}'

new "1. limit can read /nacm"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 'HTTP/1.1 200 OK' '{"ietf-netconf-acm:enable-nacm":true}' 

# Comment: it should NOT be access-denied, it should be not found, since then you say it exists but you
# dont have access to it which is insecure
new "2. guest cannot read /nacm"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

# 3. limited can read and set /config-parameters
new "3. limited can read config-parameters"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:acme-netconf/config-parameters)" 0 'HTTP/1.1 200 OK' '{"nacm-example:config-parameters":{"parameter":\[{"name":"a","value":"72"}\]}}'

new "3. limited can set config-parameters"
expectpart "$(curl -u wilma:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/nacm-example:acme-netconf/config-parameters/parameter=a -d '{"nacm-example:parameter":[{"name":"a","value":"93"}]}')" 0 'HTTP/1.1 204 No Content' 

new "4. guest cannot set /config-parameter"
expectpart "$(curl -u guest:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/nacm-example:acme-netconf/config-parameters/parameter=a -d '{"nacm-example:parameter":[{"name":"a","value":"93"}]}')" 0 'HTTP/1.1 403 Forbidden' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

# 5. limit can read and update but not create or delete dummy interface

new "5a. limit cannot create dummy interface"
expectpart "$(curl -u wilma:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/itf:interfaces -d '{"itf:interface":[{"name":"dummy","value":"93"}]}')" 0 'HTTP/1.1 403 Forbidden' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "5b. admin can create dummy interface"
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/itf:interfaces -d '{"itf:interface":[{"name":"dummy","value":"93"}]}')" 0 'HTTP/1.1 201 Created'

new "5b. admin can create other interface x as reference"
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/itf:interfaces -d '{"itf:interface":[{"name":"x","value":"200"}]}')" 0 'HTTP/1.1 201 Created'

new "5c. limit can read dummy interface"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/itf:interfaces/interface=dummy)" 0 'HTTP/1.1 200 OK' '{"itf:interface":\[{"name":"dummy","value":"93"}\]}'

new "5c. limit can read other interface"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/itf:interfaces/interface=x)" 0 'HTTP/1.1 200 OK' '{"itf:interface":\[{"name":"x","value":"200"}\]}'

new "5d. limit can update dummy interface"
expectpart "$(curl -u wilma:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/itf:interfaces/interface=dummy -d '{"itf:interface":[{"name":"dummy","value":"42"}]}')" 0 'HTTP/1.1 204 No Content'

new "5d. admin can update dummy interface"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/itf:interfaces/interface=dummy -d '{"itf:interface":[{"name":"dummy","value":"17"}]}')" 0 'HTTP/1.1 204 No Content'

new "5d. limit can not update other interface"
expectpart "$(curl -u wilma:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/itf:interfaces/interface=x -d '{"itf:interface":[{"name":"x","value":"42"}]}')" 0 'HTTP/1.1 403 Forbidden' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "5d. admin can update other interface"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/itf:interfaces/interface=x -d '{"itf:interface":[{"name":"x","value":"42"}]}')" 0 'HTTP/1.1 204 No Content'

new "5d. limit can read dummy interface (again)"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/itf:interfaces/interface=dummy)" 0 'HTTP/1.1 200 OK' '{"itf:interface":\[{"name":"dummy","value":"17"}\]}'

new "5e. limit can not delete dummy interface"
expectpart "$(curl -u wilma:bar $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/itf:interfaces/interface=dummy)" 0 'HTTP/1.1 403 Forbidden' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "5e. admin can delete dummy interface"
expectpart "$(curl -u andy:bar $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/itf:interfaces/interface=dummy)" 0 'HTTP/1.1 204 No Content' 

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf 
fi

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
