#!/usr/bin/env bash
# Authentication and authorization and IETF NACM
# NACM data node rules
# The RFC 8341 examples in the appendix are very limited.
# Here focus on datanode paths from a write perspective.
# Especially a list in a list to test vector rules
# The test uses a nested list and makes CRUD operations on one object "b"

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
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir_tmp</CLICON_YANG_DIR>
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
  container table{
    list parameter{
      key name;
      leaf name{
        type string;
      }
      container next{
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
         <name>value</name>
         <module-name>nacm-example</module-name>
         <access-operations>create delete update</access-operations>
         <path xmlns:ex="urn:example:nacm">/ex:table/ex:parameter/ex:next/ex:parameter/ex:value</path>
         <action>permit</action>
       </rule>
       <rule>
         <name>parameter</name>
         <module-name>nacm-example</module-name>
         <access-operations>read update</access-operations>
         <path xmlns:ex="urn:example:nacm">/ex:table/ex:parameter/ex:next/ex:parameter</path>
         <action>permit</action>
       </rule>

     </rule-list>

     $NADMIN

   </nacm>
EOF
)

CONFIG=$(cat <<EOF
   <table xmlns="urn:example:nacm">
     <parameter>
       <name>a</name>
       <next>
         <parameter>
           <name>a</name>
           <value>72</value>
         </parameter>
       </next>
     </parameter>
     <parameter>
       <name>b</name>
       <next>
         <parameter>
           <name>a</name>
           <value>99</value>
         </parameter>
       </next>
     </parameter>
   </table>
EOF
)

#
# Arguments, permit/deny on different levels:
# Configs (permit/deny):
# - write-default
# - param access
# - param action
# - value access
# - value action
# Tests, epxect true/false:
# - create
# - read
# - update
# - delete
function testrun(){
    writedefault=$1
    paramaccess=$2
    paramaction=$3
    valueaccess=$4
    valueaction=$5
    testc=$6
    testr=$7
    testu=$8
    testd=$9

    new "set write-default $writedefault"
    expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/write-default -d "{\"ietf-netconf-acm:write-default\":\"$writedefault\"}" )" 0 "HTTP/$HVER 204"

    new "set param rule access: $paramaccess"
    expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl/rule=parameter/access-operations -d "{\"ietf-netconf-acm:access-operations\":\"$paramaccess\"}" )" 0 "HTTP/$HVER 204"

    new "set param rule access: $paramaction"
    expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl/rule=parameter/action -d "{\"ietf-netconf-acm:action\":\"$paramaction\"}" )" 0 "HTTP/$HVER 204"

    new "set value rule access: $valueaccess"
    expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl/rule=value/access-operations -d "{\"ietf-netconf-acm:access-operations\":\"$valueaccess\"}" )" 0 "HTTP/$HVER 204"

    new "set value rule access: $valueaction"
    expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl/rule=value/action -d "{\"ietf-netconf-acm:action\":\"$valueaction\"}" )" 0 "HTTP/$HVER 204"

#--------------- Here tests: create/update/read/delete

    new "create object b"
    if $testc; then
    expectpart "$(curl -u wilma:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/nacm-example:table/parameter=a/next  -d '{"nacm-example:parameter":[{"name":"b","value":"17"}]}')" 0 "HTTP/$HVER 201"
    else
    expectpart "$(curl -u wilma:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/nacm-example:table/parameter=a/next  -d '{"nacm-example:parameter":[{"name":"b","value":"17"}]}')" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'
    fi
    new "read object b"
    if $testr; then
    expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table/parameter=a/next/parameter=b)" 0 "HTTP/$HVER 200" '{"nacm-example:parameter":\[{"name":"b","value":"17"}\]}'
    else
    expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table/parameter=a/next/parameter=b)" 0 "HTTP/$HVER 404"
    fi

    new "update object b"
    if $testu; then
    expectpart "$(curl -u wilma:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/nacm-example:table/parameter=a/next/parameter=b -d '{"nacm-example:parameter":[{"name":"b","value":"92"}]}')" 0 "HTTP/$HVER 204"
    else
	expectpart "$(curl -u wilma:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/nacm-example:table/parameter=a/next/parameter=b -d '{"nacm-example:parameter":[{"name":"b","value":"92"}]}')" 0 "HTTP/$HVER 403"
	# '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'
    fi

    new "delete object b"
    if $testd; then
    expectpart "$(curl -u wilma:bar $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/nacm-example:table/parameter=a/next/parameter=b)" 0 "HTTP/$HVER 204"
    else # XXX can vara olika
	ret=$(curl -u wilma:bar $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/nacm-example:table/parameter=a/next/parameter=b)
	r=$?
	if [ $r != 0 ]; then
	    err "retval: $r" "0"
	fi
	match1=$(echo "$ret" | grep --null -o "HTTP/$HVER 403")
	r1=$?
	match2=$(echo "$ret" | grep --null -o "HTTP/$HVER 409")
	r2=$?
	if [ $r1 != 0 -a $r2 != 0 ]; then
	    err "\"HTTP/$HVER 403\" or \"HTTP/$HVER 409\"" "$ret"
	fi
	# Ensure delete
	new "ensure delete object b"
	expectpart "$(curl -u andy:bar $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/nacm-example:table/parameter=a/next/parameter=b)" 0 "HTTP/$HVER" # ignore error
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
fi

new "wait restconf"
wait_restconf

new "auth set authentication config"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "set app config"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$CONFIG</config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "commit it"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"


new "enable nacm"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-netconf-acm:enable-nacm": true}' $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 "HTTP/$HVER 204"

#--------------- nacm enabled
# config: def param:access/action value:access/action
#                          test: create read update delete
# default deny
testrun permit "*" permit "*" permit true true true true
testrun permit "*" deny "*" deny false false false false
testrun permit "*" permit "*" deny  false false false false
testrun permit "*" permit "update delete" deny true true false false
testrun permit "*" permit "delete" deny true true true false
testrun permit "delete" deny "*" permit true true true false
testrun permit "update" deny "*" permit true true false true
testrun permit "read" deny "*" permit true false true true

testrun deny "*" permit "*" permit true true true true
testrun deny "*" permit "*" deny false false false false
testrun deny "create" permit "*" permit      true true false false
# strange: a read permit on a sub-object while default read deny opens up all
testrun deny "create read" permit "*" permit true true false false
testrun deny "create" permit "create" permit true false false false
testrun deny "create update" permit "create update" permit true false true false
testrun deny "create update delete" permit "create update delete" permit true false true true
testrun deny "create update delete" permit "update" deny true false false true
testrun deny "create update delete" permit "delete" deny true false true false
# OK but only gives sub-.object (not value) too complex to test
# testrun deny "create update read" permit "read" deny true true true false
testrun deny "*" deny "*" deny false false false false

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

new "endtest"
endtest
