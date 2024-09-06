#!/usr/bin/env bash
# Restconf media encoding, content-type / accept
# RFC 8040 5.2:
# 1. [If the Accept header is] not specified,
#    A) the request input encoding format SHOULD be used, or
#    B) the server MAY choose any supported content encoding format.
# 2. If there was no request input, then the default output encoding is
#    XML or JSON, depending on server preference.
# 3. [The client can send] a request using a specific format in the
#    "Content-Type" and/or "Accept" header field. If the server does not
#    support the requested input encoding for a request, then it MUST
#    return an error response with a "415 Unsupported Media Type"
# 4. If the server does not support any of the requested
#    output encodings for a request, then it MUST return an error response
#    with a "406 Not Acceptable" status-line.
# 5. Support list of output encodings

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/example.yang

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)
if [ $? -ne 0 ]; then
    err1 "Error when generating certs"
fi

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang
module example{
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
   rpc optional {
     description "Small RPC with optional input and output";
     input {
        leaf x {
           type string;
        }
     }
     output {
        leaf x {
           type string;
        }
     }
  }
}
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend # to be sure

    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
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
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"example:table":{"parameter":{"name":"x","value":"42"}}}' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 201"

new "restconf rpc base case"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -H "Accept: application/yang-data+json" -d '{"example:input":{"x":"abc"}}' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 200" '{"example:output":{"x":"abc"}}'

new "1A. Accept header not used, input encoding should be used (JSON)"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"example:input":{"x":"abc"}}' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 200" '{"example:output":{"x":"abc"}}'

# Not supported
#new "1A. Accept header not used, input encoding should be used (XML)"
#expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" -d '<input xmlns="urn:example:clixon"><x>abc</x></input>' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 200" '<output message-id="42" xmlns="urn:example:clixon"><x>abc</x></output>'

new "1B) the server MAY choose any supported content encoding format."
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" -d '<input xmlns="urn:example:clixon"><x>abc</x></input>' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 200" '{"example:output":{"x":"abc"}}'

new "2. If there was no request input, then the default output encoding is (XML or) JSON"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:table)" 0 "HTTP/$HVER 200" '{"example:table":{"parameter":\[{"name":"x","value":"42"}\]}}'

new "3. Not supported format: (none) expect 415"
expectpart "$(curl $CURLOPTS -X POST -d '<input xmlns="urn:example:clixon"><x>abc</x></input>' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 415"

new "3. Not supported format: (image) expect 415"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: image/avif" -d '<input xmlns="urn:example:clixon"><x>abc</x></input>' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 415"

new "4. Server does not support output encodings expect 406"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" -H "Accept: image/avif" -d '<input xmlns="urn:example:clixon"><x>abc</x></input>' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 406"

new "4. Server does not support list of output encodings expect 406"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" -H "Accept: image/avif,application/xhtml+xml" -d '<input xmlns="urn:example:clixon"><x>abc</x></input>' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 406"

new "5. List of encodings, including *"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" -H "Accept: image/avif,*/*" -d '<input xmlns="urn:example:clixon"><x>abc</x></input>' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 200" '{"example:output":{"x":"abc"}}'

new "5. List of encodings, accept JSON"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml"  -H "Accept: image/avif,application/yang-data+json" -d '<input xmlns="urn:example:clixon"><x>abc</x></input>' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 200" '{"example:output":{"x":"abc"}}'

new "5. List of encodings, accept XML"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml"  -H "Accept: image/avif,application/yang-data+xml" -d '<input xmlns="urn:example:clixon"><x>abc</x></input>' $RCPROTO://localhost/restconf/operations/example:optional)" 0 "HTTP/$HVER 200" '<output message-id="42" xmlns="urn:example:clixon"><x>abc</x></output>'

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

rm -rf $dir

new "endtest"
endtest
