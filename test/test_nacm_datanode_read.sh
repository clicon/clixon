#!/usr/bin/env bash
# Authentication and authorization and IETF NACM
# NACM data node rules
# The RFC 8341 examples in the appendix are very limited.
# Here focus on datanode paths from a read perspective.
# The limit user is used for this
# The following shows a tree of the paths where permit/deny actions can be set:
# read-default
#   module
#     /table
#       /table/parameters/parameter
#
# The test goes through all permutations and checks the expected behaviour
# 

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang
fyang2=$dir/nacm-example2.yang

# Define default restconfig config: RESTCONFIG
restconf_config user false

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
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang
module nacm-example{
  yang-version 1.1;
  namespace "urn:example:nacm";
  prefix ex;
  import ietf-netconf-acm {
    prefix nacm;
  } 
  import nacm-example2 {
    prefix ex2;
  } 
  container table{
    container parameters{
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
  container other{
    leaf value{
      type string;
    }
  }
}
EOF

cat <<EOF > $fyang2
module nacm-example2{
  yang-version 1.1;
  namespace "urn:example:nacm2";
  prefix ex2;
  container other2{
    leaf value{
      type string;
    }
  }
}
EOF

RULES=$(cat <<EOF
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>false</enable-nacm>
     <read-default>deny</read-default>
     <write-default>deny</write-default>
     <exec-default>permit</exec-default>

     $NGROUPS

     <rule-list>
       <name>limited-acl</name>
       <group>limited</group>

       <rule>
         <name>parameter</name>
         <module-name>*</module-name>
         <access-operations>read</access-operations>
         <path xmlns:ex="urn:example:nacm">/ex:table/ex:parameters/ex:parameter</path>
         <action>permit</action>
       </rule>
       <rule>
         <name>table</name>
         <module-name>*</module-name>
         <access-operations>read</access-operations>
         <path xmlns:ex="urn:example:nacm">/ex:table</path>
         <action>permit</action>
       </rule>
       <rule>
         <name>module</name>
         <module-name>nacm-example</module-name>
         <access-operations>read</access-operations>
         <action>permit</action>
       </rule>

     </rule-list>

     $NADMIN

   </nacm>
EOF
)

CONFIG=$(cat <<EOF
   <table xmlns="urn:example:nacm">
     <parameters>
       <parameter>
         <name>a</name>
         <value>72</value>
       </parameter>
     </parameters>
   </table>
   <other xmlns="urn:example:nacm">
     <value>99</value>
   </other>
   <other2 xmlns="urn:example:nacm2">
     <value>88</value>
   </other2>
EOF
)

#
# Arguments, permit/deny on different levels:
# Configs (permit/deny):
# - read-default
# - module as a whole
# - table: root symbol
# - param: sub symbol
# Tests, epxect true/false:
# - read other module
# - read other in same module
# - read table
# - read parameter
function testrun(){
    readdefault=$1
    module=$2
    table=$3
    parameter=$4
    test1=$5
    test2=$6
    test3=$7
    test4=$8

    new "read-default:$readdefault module:$module table:$table parameter:$parameter"

    new "set read-default $readdefault"
    expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/read-default -d "{\"ietf-netconf-acm:read-default\":\"$readdefault\"}" )" 0 "HTTP/1.1 204 No Content"

    new "set module rule $module"
    expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl/rule=module/action -d "{\"ietf-netconf-acm:action\":\"$module\"}" )" 0 "HTTP/1.1 204 No Content"

    new "set table rule $table"
    expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl/rule=table/action -d "{\"ietf-netconf-acm:action\":\"$table\"}" )" 0 "HTTP/1.1 204 No Content"

    new "set parameter rule $parameter"
    expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl/rule=parameter/action -d "{\"ietf-netconf-acm:action\":\"$parameter\"}" )" 0 "HTTP/1.1 204 No Content"

#--------------- Here check
    new "get other module"
    if $test1; then
    expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example2:other2/value)" 0 'HTTP/1.1 200 OK' '{"nacm-example2:value":"88"}'
    else
    expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example2:other2/value)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'
    fi

    new "get other in same module"
    if $test2; then
    expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:other/value)" 0 'HTTP/1.1 200 OK' '{"nacm-example:value":"99"}'
    else
    expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:other/value)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'
    fi

    new "get table"
    if $test3; then
	expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table?depth=1)" 0 'HTTP/1.1 200 OK' '{"nacm-example:table":{}}'
    else
	expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table?depth=1)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'
    fi
    new "get parameter"
    if $test4; then
    expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table/parameters/parameter=a)" 0 'HTTP/1.1 200 OK' '{"nacm-example:parameter":\[{"name":"a","value":"72"}\]}'
    else
    expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table/parameters/parameter=a)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'
    fi

} # testrun

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

    new "waiting"
    wait_restconf
fi

new "auth set authentication config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "set app config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$CONFIG</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "commit it"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"


new "enable nacm"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-netconf-acm:enable-nacm": true}' $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 "HTTP/1.1 204 No Content"

#--------------- nacm enabled
# config: def module  table  parameter
#                            test:  mod   other table parameter
# default deny
testrun deny   deny   deny   deny   false false false false
testrun deny   deny   deny   permit false false false false
testrun deny   deny   permit deny   false false true  false
testrun deny   deny   permit permit false false true  true

testrun deny   permit deny   deny   false true  false false
testrun deny   permit deny   permit false true  false false
testrun deny   permit permit deny   false true  true  false
testrun deny   permit permit permit false true  true  true

# default permit
testrun permit deny   deny   deny   true  false false false
testrun permit deny   deny   permit true  false false false
testrun permit deny   permit deny   true  false true false
testrun permit deny   permit permit true  false true  true

testrun permit permit deny   deny   true  true  false false
testrun permit permit deny   permit true  true  false false
testrun permit permit permit deny   true  true  true  false
testrun permit permit permit permit true  true  true  true

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf 
fi
if [ $BE -ne 0 ]; then     # Bring your own backend
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
