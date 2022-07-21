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

# Override default to use http/1.1

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Does not work with native http/2-only
if [ "${WITH_RESTCONF}" = "native" -a ${HAVE_HTTP1} = false ]; then
#if ! ${HAVE_HTTP1}; then
    echo "...skipped: must run with http/1"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# Pin to http/1
if [ ${HAVE_LIBNGHTTP2} = true -a ${HAVE_HTTP1} = true ]; then
    HAVE_LIBNGHTTP2=false
    CURLOPTS="${CURLOPTS} --http1.1"
    HVER=1.1
fi

# Force to HTTP 1.1 no SSL due to netcat
RCPROTO=http

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/example.yang
fyang2=$dir/augment.yang
fxml=$dir/initial.xml
fstate=$dir/state.xml

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
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
    start_backend -s init -f $cfg -- -sS $fstate -V "/table/parameter[name='4242']"
fi

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

new "restconf POST initial tree"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' -d "$XML" $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 201"

new "restconf GET initial datastore"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:a=0)" 0 "HTTP/$HVER 200" "$XML"

if [ -n "$netcat" -a "${WITH_RESTCONF}" != "fcgi" ]; then

#    new "restconf try fuzz crash"
#    expectpart "$(${netcat} 127.0.0.1 80 < ~/tmp/crashes/id:000000,sig:06,src:000493+000365,op:splice,rep:8)" 0 "HTTP/$HVER 400"
    
    new "netcat restconf GET initial datastore netcat"
    expectpart "$(${netcat} 127.0.0.1 80 <<EOF
GET /restconf/data/example:a=0 HTTP/$HVER
Host: localhost
Accept: application/yang-data+xml

EOF
)" 0 "HTTP/$HVER 200" "$XML"

    new "netcat restconf XYZ not found"
    expectpart "$(${netcat} 127.0.0.1 80 <<EOF
XYZ /restconf/data/example:a=0 HTTP/$HVER
Host: localhost
Accept: application/yang-data+xml

EOF
)" 0 "HTTP/$HVER 404"
    
    new "netcat restconf PUT not allowed"
    expectpart "$(${netcat} 127.0.0.1 80 <<EOF
PUT /.well-known/host-meta HTTP/$HVER
Host: localhost
Accept: application/yang-data+xml

EOF
)" 0 "HTTP/$HVER 405" # nginx uses "method not allowed" 

if false; then # XXX >50% does not work on docker alpine
    new "netcat restconf GET wrong http version raw"
    expectpart "$(${netcat} 127.0.0.1 80 <<EOF
GET /restconf/data/example:a=0 HTTP/a.1
Host: localhost
Accept: application/yang-data+xml


EOF
)" 0 "HTTP/$HVER 400" # native: '<error-tag>malformed-message</error-tag><error-message>The requested URL or a header is in some way badly formed</error-message>'

    fi
fi # netcat Cannot get to work on all platforms

new "restconf XYZ not found"
expectpart "$(curl $CURLOPTS -X XYS -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:a=0)" 0 "HTTP/$HVER 404"

new "restconf PUT not allowed"
expectpart "$(curl $CURLOPTS -X PUT $RCPROTO://localhost/.well-known/host-meta)" 0 "HTTP/$HVER 405" "Allow: GET,HEAD"

new "restconf GET non-qualified list"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:a)" 0 "HTTP/$HVER 400" "{\"ietf-restconf:errors\":{\"error\":{\"error-type\":\"rpc\",\"error-tag\":\"malformed-message\",\"error-severity\":\"error\",\"error-message\":\"malformed key =example:a, expected '=restval'\"}}}"

new "restconf GET container with rest-api"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:table=x)" 0 "HTTP/$HVER 400" "{\"ietf-restconf:errors\":{\"error\":{\"error-type\":\"rpc\",\"error-tag\":\"malformed-message\",\"error-severity\":\"error\",\"error-message\":\"malformed api-path, =x not expected\"}}}"

new "restconf GET non-qualified list subelements"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:a/k)" 0 "HTTP/$HVER 400" "^{\"ietf-restconf:errors\":{\"error\":{\"error-type\":\"rpc\",\"error-tag\":\"malformed-message\",\"error-severity\":\"error\",\"error-message\":\"malformed key =example:a, expected '=restval'\"}}}"

new "restconf GET non-existent container body"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:a=0/c)" 0 "HTTP/$HVER 404" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

new "restconf GET invalid (no yang) container body"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:a=0/xxx)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"xxx"},"error-severity":"error","error-message":"Unknown element"}}}'

new "restconf GET invalid (no yang) element"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:xxx)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"xxx"},"error-severity":"error","error-message":"Unknown element"}}}'

new "restconf POST non-existent (no yang) element"
# should be invalid element
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' -d "$XML" $RCPROTO://localhost/restconf/data/example:a=23/xxx)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"xxx"},"error-severity":"error","error-message":"Unknown element"}}}'

# Test for multi-module path where an augment stretches across modules
new "restconf POST augment multi-namespace path"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' -d '<route-config xmlns="urn:example:aug"><dynamic><ospf xmlns="urn:example:clixon"><reference-bandwidth>23</reference-bandwidth></ospf></dynamic></route-config>' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 201"

new "restconf GET augment multi-namespace top"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/augment:route-config)" 0 "HTTP/$HVER 200" '{"augment:route-config":{"dynamic":{"example:ospf":{"reference-bandwidth":23}}}}'

new "restconf GET augment multi-namespace level 1"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/augment:route-config/dynamic)" 0 "HTTP/$HVER 200" '{"augment:dynamic":{"example:ospf":{"reference-bandwidth":23}}}'

new "restconf GET augment multi-namespace cross"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/augment:route-config/dynamic/example:ospf)" 0 "HTTP/$HVER 200" '{"example:ospf":{"reference-bandwidth":23}}'

new "restconf GET augment multi-namespace cross level 2"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/augment:route-config/dynamic/example:ospf/reference-bandwidth)" 0 "HTTP/$HVER 200" '{"example:reference-bandwidth":23}'

# XXX actually no such element
new "restconf GET augment multi-namespace, no 2nd module in api-path, fail"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/augment:route-config/dynamic/ospf)" 0 "HTTP/$HVER 404" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

#----------------------------------------------
# Also generate an invalid state XML. This should generate an "Internal" error and the name of the
new "restconf GET failed state"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data?content=nonconfig)" 0 "HTTP/$HVER 412" '<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-info><bad-element>mystate</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: mystate with parent: config in namespace: urn:example:foobar. Internal error, state callback returned invalid XML from plugin: example_backend</error-message></error></errors>'

# Add error XML a[4242] , it should fail on autocommit but may not be discarded, therefore still
# there in candidate when want to add something else
new "Add user-invalid entry (should fail)"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data -d '<table xmlns="urn:example:clixon"><parameter><name>4242</name></parameter></table>')" 0 "HTTP/$HVER 412" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"operation-failed","error-severity":"error","error-message":"User error"}}}'

new "Add OK entry"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data -d '<table xmlns="urn:example:clixon"><parameter><name>1</name></parameter></table>')" 0 "HTTP/$HVER 201" 

new "Multiple requests: POST + POST" # XXX Do for HTTP/1 ALSO
expectpart "$(curl $CURLOPTS -H "Content-Type: application/yang-data+json" -X POST $RCPROTO://localhost/restconf/data/example:table -d '{"example:parameter":{"name":"local1","value":"nisse"}}' --next $CURLOPTS -H "Content-Type: application/yang-data+json" -X POST $RCPROTO://localhost/restconf/data/example:table -d '{"example:parameter":{"name":"local2","value":"laban"}}')" 0 "HTTP/$HVER 201" "localhost/restconf/data/example:table/parameter=local1" "localhost/restconf/data/example:table/parameter=local2"

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
unset HVER
unset RCPROTO
unset CURLOPTS
unset HAVE_LIBNGHTTP2

rm -rf $dir

new "endtest"
endtest
