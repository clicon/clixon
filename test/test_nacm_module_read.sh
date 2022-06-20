#!/usr/bin/env bash
# Authentication and authorization and IETF NACM
# NACM module rules
# A module rule has the "module-name" leaf set but no nodes from the
# "rule-type" choice set.
# @see test_nacm.sh is slightly modified - this follows the RFC more closely
# See RFC 8341 A.1 and A.2
# Note: use clixon-example instead of ietf-netconf-monitoring since the latter is

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang
fyang2=$dir/clixon-example.yang

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config user false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_CREDENTIALS>none</CLICON_NACM_CREDENTIALS>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang
module nacm-example{
  yang-version 1.1;
  namespace "urn:example:nacm";
  prefix nex;
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

cat <<EOF > $fyang2
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  container table{
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
    /* State data (not config) for the example application*/
    container state {
         config false;
         description "state data for the example application (must be here for example get operation)";
         leaf-list op {
            type string;
         }
    }
    rpc example {
	description "Some example input/output for testing RFC7950 7.14.
                     RPC simply echoes the input for debugging.";
	input {
	    leaf x {
		description
         	    "If a leaf in the input tree has a 'mandatory' statement with
                   the value 'true', the leaf MUST be present in an RPC invocation.";
		type string;
		mandatory true;
	    }
	    leaf y {
		description
                 "If a leaf in the input tree has a 'mandatory' statement with the
                  value 'true', the leaf MUST be present in an RPC invocation.";
		type string;
		default "42";
	    }
      }
      output {
	    leaf x {
		type string;
	    }
	    leaf y {
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
   <table xmlns="urn:example:clixon"><parameter><name>key42</name><value>val42</value></parameter>
           b<parameter><name>key43</name><value>val43</value></parameter></table>
EOF
)

new "test params: -f $cfg -- -s"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg -- -s"
    start_backend -s init -f $cfg -- -s
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
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit it"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "enable nacm"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-netconf-acm:enable-nacm": true}' $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/enable-nacm)" 0 "HTTP/$HVER 204"

#--------------- nacm enabled

#----READ access
#user:admin
new "admin read ok"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:table)" 0 "HTTP/$HVER 200" '{"clixon-example:table":{"parameter":\[{"name":"key42","value":"val42"},{"name":"key43","value":"val43"}\]}}'

new "admin read netconf ok"
expecteof_netconf "$clixon_netconf -U andy -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/t:table\" xmlns:t=\"urn:example:clixon\" /></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><parameter><name>key42</name><value>val42</value></parameter><parameter><name>key43</name><value>val43</value></parameter></table></data></rpc-reply>"

new "admin read element ok"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:table/parameter=key42/value)" 0 "HTTP/$HVER 200" '{"clixon-example:value":"val42"}'

new "admin read other module OK"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 200" '{"nacm-example:x":42}'

new "admin read state OK"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:state)" 0 "HTTP/$HVER 200" '{"clixon-example:state":{"op":\["41","42","43"\]}}'

new "admin read top ok (all)"
ret=$(curl -u andy:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data)
expect='{"ietf-restconf:data":{"clixon-example:table":'
match=`echo $ret | grep "$expect"`
if [ -z "$match" ]; then
    err "$expect" "$ret"
fi

#user:limit

new "limit read ok"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:table)" 0 "HTTP/$HVER 200" '{"clixon-example:table":{"parameter":\[{"name":"key42","value":"val42"},{"name":"key43","value":"val43"}\]}}'

new "limit read netconf ok"
expecteof_netconf "$clixon_netconf -U wilma -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/t:table\" xmlns:t=\"urn:example:clixon\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><parameter><name>key42</name><value>val42</value></parameter><parameter><name>key43</name><value>val43</value></parameter></table></data></rpc-reply>"

new "limit read element ok"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:table/parameter=key42/value)" 0 "HTTP/$HVER 200" '{"clixon-example:value":"val42"}'

new "limit read other module fail"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 404" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

new "limit read state OK"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:state)" 0 "HTTP/$HVER 200" '{"clixon-example:state":{"op":\["41","42","43"\]}}'

new "limit read top ok (part)"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 200" '{"ietf-restconf:data":{"clixon-example:table":{"parameter":\[{"name":"key42","value":"val42"},{"name":"key43","value":"val43"}\]},"clixon-example:state":{"op":\["41","42","43"\]}}}'

#user:guest

new "guest read forbidden"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:table)" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "guest read netconf fail"
expecteof_netconf "$clixon_netconf -U guest -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/t:table\" xmlns:t=\"urn:example:clixon\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>default deny</error-message></rpc-error></rpc-reply>"

new "guest read element forbidden"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:table/parameter=key42/value)" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "guest read other module fail"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "guest read state fail"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:state)" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

new "guest read top ok (part)"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

#------- RPC operation

new "admin rpc ok"
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":"78"}}' $RCPROTO://localhost/restconf/operations/clixon-example:example)" 0 "HTTP/$HVER 200" '{"clixon-example:output":{"x":"78","y":"42"}}'

new "admin rpc netconf ok"
expecteof_netconf "$clixon_netconf -U andy -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><example xmlns=\"urn:example:clixon\"><x>0</x></example></rpc>" "" "<rpc-reply $DEFAULTNS><x xmlns=\"urn:example:clixon\">0</x><y xmlns=\"urn:example:clixon\">42</y></rpc-reply>"

new "limit rpc ok"
expectpart "$(curl -u wilma:bar $CURLOPTS -X POST $RCPROTO://localhost/restconf/operations/clixon-example:example -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":42}}' )" 0 "HTTP/$HVER 200" '{"clixon-example:output":{"x":"42","y":"42"}}'

new "limit rpc netconf ok"
expecteof_netconf "$clixon_netconf -U wilma -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><example xmlns=\"urn:example:clixon\"><x>0</x></example></rpc>" "" "<rpc-reply $DEFAULTNS><x xmlns=\"urn:example:clixon\">0</x><y xmlns=\"urn:example:clixon\">42</y></rpc-reply>"

new "guest rpc fail"
expectpart "$(curl -u guest:bar $CURLOPTS -X POST $RCPROTO://localhost/restconf/operations/clixon-example:example -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":42}}' )" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"access denied"}}}'

new "guest rpc netconf fail"
expecteof_netconf "$clixon_netconf -U guest -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><example xmlns=\"urn:example:clixon\"><x>0</x></example></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>access denied</error-message></rpc-error></rpc-reply>"

#------------------ Set read-default permit

new "admin set read-default permit"
expectpart "$(curl -u andy:bar $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-netconf-acm:read-default":"permit"}' $RCPROTO://localhost/restconf/data/ietf-netconf-acm:nacm/read-default)" 0 "HTTP/$HVER 204"

new "limit read ok"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:table)" 0 "HTTP/$HVER 200" '{"clixon-example:table":{"parameter":\[{"name":"key42","value":"val42"},{"name":"key43","value":"val43"}\]}}'

new "limit read other module ok"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/nacm-example:x)" 0 "HTTP/$HVER 200" '{"nacm-example:x":42}'

new "guest read state fail"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-example:state)" 0 "HTTP/$HVER 403" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf 
fi

if [ $BE -ne 0 ]; then
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
unset ret

rm -rf $dir

new "endtest"
endtest
