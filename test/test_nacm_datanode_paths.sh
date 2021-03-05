#!/usr/bin/env bash
# NACM data node rules
# Other NACM datanode tests assume a fixed NACM PATH ruleset
# These tests add and changes datanode rules in paths
# There is problems with namespace for paths
# See test_nacm_datanode_read.sh for original RULES for limit which are here added dynamically
# 

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang

# Define default restconfig config: RESTCONFIG
restconf_config user false

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_CREDENTIALS>none</CLICON_NACM_CREDENTIALS>
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
}
EOF

# Set initial NACM rules in startup enabling admin and a single param config
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
   <table xmlns="urn:example:nacm">
     <parameters>
       <parameter>
         <name>a</name>
         <value>72</value>
       </parameter>
     </parameters>
   </table>

   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>true</enable-nacm>
     <read-default>deny</read-default>
     <write-default>deny</write-default>
     <exec-default>permit</exec-default>
     $NGROUPS
     $NADMIN
   </nacm>
</${DATASTORE_TOP}>
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
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

new "admin read OK"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table/parameters/parameter=a)" 0 'HTTP/1.1 200 OK' '{"nacm-example:parameter":\[{"name":"a","value":"72"}\]}'

new "Fail limit read"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table/parameters/parameter=a)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

# Add NACM read rule
new "Add NACM read path rule XML"
expectpart "$(curl -u andy:bar $CURLOPTS -X POST $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm -H 'Content-Type: application/yang-data+xml' -d '<rule-list xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm"><name>limited-acl</name><group>limited</group><rule><name>table</name><module-name>*</module-name><access-operations>read</access-operations><path xmlns:ex="urn:example:nacm">/ex:table</path><action>permit</action></rule></rule-list>')" 0 "HTTP/1.1 201 Created"

new "Read NACM rule"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl)" 0  "HTTP/1.1 200 OK" '{"ietf-netconf-acm:rule-list":\[{"name":"limited-acl","group":"limited","rule":\[{"name":"table","module-name":"\*","path":"/ex:table","access-operations":"read","action":"permit"}\]}\]}'

new "limit read OK"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table/parameters/parameter=a)" 0 'HTTP/1.1 200 OK' '{"nacm-example:parameter":\[{"name":"a","value":"72"}\]}'

new "Delete NACM read rule"
expectpart "$(curl -u andy:bar $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl)" 0 "HTTP/1.1 204 No Content"

new "Fail limit read"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table/parameters/parameter=a)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

new "Add NACM read path rule JSON"
expectpart "$(curl -u andy:bar $CURLOPTS -X POST  $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm -H 'Content-Type: application/yang-data+json' -d '{"ietf-netconf-acm:rule-list":[{"name":"limited-acl","group":"limited","rule":[{"name":"table","module-name":"*","path":"/ex:table","access-operations":"read","action":"permit"}]}]}')" 0 "HTTP/1.1 201 Created"

new "Read NACM rule"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl)" 0  "HTTP/1.1 200 OK" '{"ietf-netconf-acm:rule-list":\[{"name":"limited-acl","group":"limited","rule":\[{"name":"table","module-name":"\*","path":"/ex:table","access-operations":"read","action":"permit"}\]}\]}'

new "limit read OK (Set rul w JSON)"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table/parameters/parameter=a)" 0 'HTTP/1.1 200 OK' '{"nacm-example:parameter":\[{"name":"a","value":"72"}\]}'

new "Delete NACM read rule"
expectpart "$(curl -u andy:bar $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/rule-list=limited-acl)" 0 "HTTP/1.1 204 No Content"

new "Fail limit read"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:table/parameters/parameter=a)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

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
