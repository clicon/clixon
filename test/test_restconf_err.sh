#!/usr/bin/env bash
# Restconf error-code functionality
# See RFC8040
# Testcases:
# Sec 4.3 (GET): If a retrieval request for a data resource represents an
# instance that does not exist, then an error response containing a "404 Not
# Found" status-line MUST be returned by the server.  The error-tag
# value "invalid-value" is used in this case.
# RFC 7231:
# Response messages with an error status code
# usually contain a payload that represents the error condition, such
# that it describes the error state and what next steps are suggested
# for resolving it.
#
# Note this is different from an api-path that is invalid from a yang point
# of view, this is interpreted as 400 Bad Request invalid-value/unknown-element
# XXX: complete non-existent yang with unknown-element for all PUT/POST/GET api-paths
#
# Also generate an invalid state XML. This should generate an "Internal" error and the name of the
# plugin should be visible in the error message.
# XXX does not test rpc-error from backend in api_return_err?

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/example.yang
fyang2=$dir/augment.yang
fxml=$dir/initial.xml
fstate=$dir/state.xml
RCPROTO=http # Force to http due to netcat


# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang2
module augment{
   yang-version 1.1;
   namespace "urn:example:aug";
   prefix aug;
   description "Used as a base for augment";
   container route-config {
	description
	    "Root container for routing models";
	container dynamic {
	}
   }
   container route-state {
	description
	    "Root container for routing models";
	config "false";
	container dynamic {
	}
   }
}
EOF

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   import augment {
        description "Just for augment";
	prefix "aug";
   }

   list a {
      key k;
      leaf k {
         type int32;
      }
      leaf description{
         type string;
      }
      leaf b{
         type string;
      }
      container c{
         presence "for test";
      }
      list d{
         key k;
         leaf k {
            type string;
         }
      }
   }
   augment "/aug:route-config/aug:dynamic" {
      container ospf {
         leaf reference-bandwidth {
	    type uint32;
         }
      }
   }
   container mystate{
      config false;
      description "Just for generating a invalid XML";
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
}
EOF

# State file with error: wrong namespace
cat <<EOF > $fstate
<mystate xmlns="urn:example:foobar">
   <parameter>
      <name>x</name>
      <value>x</value>
   </parameter>
</mystate>
EOF

# Initial tree
XML=$(cat <<EOF
<a xmlns="urn:example:clixon"><k>0</k><description>No leaf b, No container c, No leaf d</description></a>
EOF
   )

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure
    new "start backend -s init -f $cfg -- -sS $fstate -v /table/parameter[name=\"4242\"]"
    start_backend -s init -f $cfg -- -sS $fstate -v /table/parameter[name="4242"]
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

new "restconf POST initial tree"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' -d "$XML" $RCPROTO://localhost/restconf/data)" 0 'HTTP/1.1 201 Created'

new "restconf GET initial datastore"
#echo "curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:a=0"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:a=0)" 0 'HTTP/1.1 200 OK' "$XML"

# XXX cannot get this to work for all combinations of nc/netcat fcgi/native
# But leave it here for debugging where netcat works properly
if false; then
    # Look for netcat or nc for direct socket http calls
    if [ -n "$(type netcat 2> /dev/null)" ]; then
	netcat="netcat -w 1" # -N works on evhtp but not fcgi
    elif [ -n "$(type nc 2> /dev/null)" ]; then
	netcat=nc
    else
	err1 "netcat/nc not found"
    fi

    new "restconf GET initial datastore netcat"
    expectpart "$(${netcat} 127.0.0.1 80 <<EOF
GET /restconf/data/example:a=0 HTTP/1.1
Host: localhost
Accept: application/yang-data+xml

EOF
)" 0 "HTTP/1.1 200 OK" "$XML"

    new "restconf XYZ not found"
    expectpart "$(${netcat} 127.0.0.1 80 <<EOF
XYZ /restconf/data/example:a=0 HTTP/1.1
Host: localhost
Accept: application/yang-data+xml

EOF
)" 0 "HTTP/1.1 404 Not Found"
    
    new "restconf HEAD not allowed"
    expectpart "$(${netcat} 127.0.0.1 80 <<EOF
HEAD /restconf HTTP/1.1
Host: localhost
Accept: application/yang-data+xml

EOF
)" 0 "HTTP/1.1 405" "Not Allowed" # nginx uses "method not allowed" evhtp "not allowed"
fi # Cannot get to work

new "restconf XYZ not found"
expectpart "$(curl $CURLOPTS -X XYS -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:a=0)" 0 'HTTP/1.1 404 Not Found'

# XXX dont work w fcgi
if [ "${WITH_RESTCONF}" = "native" ]; then
    new "restconf HEAD not allowed"
    expectpart "$(curl $CURLOPTS -X HEAD -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf)" 0 "HTTP/1.1 405" "Not Allowed"
fi

new "restconf GET non-qualified list"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:a)" 0 'HTTP/1.1 400 Bad Request' "{\"ietf-restconf:errors\":{\"error\":{\"error-type\":\"rpc\",\"error-tag\":\"malformed-message\",\"error-severity\":\"error\",\"error-message\":\"malformed key =example:a, expected '=restval'\"}}}"

new "restconf GET non-qualified list subelements"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:a/k)" 0 'HTTP/1.1 400 Bad Request' "^{\"ietf-restconf:errors\":{\"error\":{\"error-type\":\"rpc\",\"error-tag\":\"malformed-message\",\"error-severity\":\"error\",\"error-message\":\"malformed key =example:a, expected '=restval'\"}}}"

new "restconf GET non-existent container body"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:a=0/c)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

new "restconf GET invalid (no yang) container body"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:a=0/xxx)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"xxx"},"error-severity":"error","error-message":"Unknown element"}}}'

new "restconf GET invalid (no yang) element"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:xxx)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"xxx"},"error-severity":"error","error-message":"Unknown element"}}}'

new "restconf POST non-existent (no yang) element"
# should be invalid element
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' -d "$XML" $RCPROTO://localhost/restconf/data/example:a=23/xxx)" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"xxx"},"error-severity":"error","error-message":"Unknown element"}}}'

# Test for multi-module path where an augment stretches across modules
new "restconf POST augment multi-namespace path"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' -d '<route-config xmlns="urn:example:aug"><dynamic><ospf xmlns="urn:example:clixon"><reference-bandwidth>23</reference-bandwidth></ospf></dynamic></route-config>' $RCPROTO://localhost/restconf/data)" 0 'HTTP/1.1 201 Created'

new "restconf GET augment multi-namespace top"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/augment:route-config)" 0 'HTTP/1.1 200 OK' '{"augment:route-config":{"dynamic":{"example:ospf":{"reference-bandwidth":23}}}}'

new "restconf GET augment multi-namespace level 1"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/augment:route-config/dynamic)" 0 'HTTP/1.1 200 OK' '{"augment:dynamic":{"example:ospf":{"reference-bandwidth":23}}}'

new "restconf GET augment multi-namespace cross"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/augment:route-config/dynamic/example:ospf)" 0 'HTTP/1.1 200 OK' '{"example:ospf":{"reference-bandwidth":23}}'

new "restconf GET augment multi-namespace cross level 2"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/augment:route-config/dynamic/example:ospf/reference-bandwidth)" 0 'HTTP/1.1 200 OK' '{"example:reference-bandwidth":23}'

# XXX actually no such element
new "restconf GET augment multi-namespace, no 2nd module in api-path, fail"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/augment:route-config/dynamic/ospf)" 0 'HTTP/1.1 404 Not Found' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

#----------------------------------------------
# Also generate an invalid state XML. This should generate an "Internal" error and the name of the
new "restconf GET failed state"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data?content=nonconfig)" 0 '412 Precondition Failed' '<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-info><bad-element>mystate</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: mystate with parent: config in namespace: urn:example:foobar. Internal error, state callback returned invalid XML from plugin: example_backend</error-message></error></errors>'

# Add error XML a[4242] , it should fail on autocommit but may not be discarded, therefore still
# there in candidate when want to add something else
new "Add user-invalid entry (should fail)"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data -d '<table xmlns="urn:example:clixon"><parameter><name>4242</name></parameter></table>')" 0 "HTTP/1.1 412 Precondition Failed" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"operation-failed","error-severity":"error","error-message":"User error"}}}'

new "Add OK entry"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data -d '<table xmlns="urn:example:clixon"><parameter><name>1</name></parameter></table>')" 0 "HTTP/1.1 201 Created" 

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

rm -rf $dir

new "endtest"
endtest
