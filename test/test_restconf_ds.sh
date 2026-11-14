#!/usr/bin/env bash
# RESTCONF datastore resources, RFC 8527 Sec 3.1:
#   {+restconf}/ds/<datastore> refers to that datastore.
# - GET of running, candidate and startup reads that datastore, config only
#   (content=nonconfig yields nothing, depth is honored)
# - running and startup are read-only resources: PUT, PATCH, POST and DELETE
#   fail with 405 (RFC 8527 Sec 3.2) and change nothing
# - operational is config in use plus state, read-only
# - startup is not a resource unless :startup is implemented
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/example.yang

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   container x {
     list y {
       key "a";
       leaf a {
         type string;
       }
       container z {
         leaf b {
           type string;
         }
       }
     }
   }
}
EOF

RESTCONFIG=$(restconf_config none false)
if [ $? -ne 0 ]; then
    err1 "Error when generating certs"
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  $RESTCONFIG
</clixon-config>
EOF

JSON="Content-Type: application/yang-data+json"
DS=$RCPROTO://localhost/restconf/ds/ietf-datastores
DATA=$RCPROTO://localhost/restconf/data
OPS=$RCPROTO://localhost/restconf/operations

function start(){
    option=$1
    new "test params: -f $cfg $option"
    if [ $BE -ne 0 ]; then
        new "kill old backend"
        sudo clixon_backend -zf $cfg
        new "start backend -s init -f $cfg $option"
        start_backend -s init -f $cfg $option
    fi
    new "wait backend"
    wait_backend
    if [ $RC -ne 0 ]; then
        new "kill old restconf daemon"
        stop_restconf_pre
        new "start restconf daemon"
        start_restconf -f $cfg $option
    fi
    new "wait restconf"
    wait_restconf
}

function stop(){
    if [ $RC -ne 0 ]; then
        new "Kill restconf daemon"
        stop_restconf
    fi
    if [ $BE -ne 0 ]; then
        new "Kill backend"
        stop_backend -f $cfg
    fi
}

# --------------------------------------------------------------------
start "-o CLICON_FEATURE=ietf-netconf:startup"

new "PUT y=1 via data resource"
expectpart "$(curl $CURLOPTS -X PUT -H "$JSON" $DATA/example:x/y=1 -d '{"example:y":[{"a":"1","z":{"b":"one"}}]}')" 0 "HTTP/$HVER 201"

new "netconf: stage y=2 in candidate, no commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>2</a></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "GET ds/candidate shows staged y=2"
expectpart "$(curl $CURLOPTS -X GET $DS:candidate/example:x)" 0 "HTTP/$HVER 200" '"a":"2"'

new "GET ds/running does not show y=2"
expectpart "$(curl $CURLOPTS -X GET $DS:running/example:x/y=2)" 0 "HTTP/$HVER 404"

new "GET data does not show y=2"
expectpart "$(curl $CURLOPTS -X GET $DATA/example:x/y=2)" 0 "HTTP/$HVER 404"

new "HEAD ds/candidate y=2 exists"
expectpart "$(curl $CURLOPTS -I $DS:candidate/example:x/y=2)" 0 "HTTP/$HVER 200"

new "GET ds/candidate content=nonconfig: conventional datastores hold no state"
expectpart "$(curl $CURLOPTS -X GET "$DS:candidate/example:x?content=nonconfig")" 0 "HTTP/$HVER 404"

new "GET ds/running depth=2 omits y contents"
ret=$(curl $CURLOPTS -X GET "$DS:running?depth=2")
expectpart "$ret" 0 "HTTP/$HVER 200" '"example:x":{"y"' --not-- '"b":"one"'

new "GET ds/running depth=4 includes y contents"
expectpart "$(curl $CURLOPTS -X GET "$DS:running?depth=4")" 0 "HTTP/$HVER 200" '"b":"one"'

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf: y=9 in running via commit (does not update startup)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>9</a></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "GET ds/startup reads startup: y=1 (copied by the data PUT), not y=9"
expectpart "$(curl $CURLOPTS -X GET $DS:startup/example:x)" 0 "HTTP/$HVER 200" '"a":"1"' --not-- '"a":"9"'

new "GET ds/running has y=9"
expectpart "$(curl $CURLOPTS -X GET $DS:running/example:x/y=9)" 0 "HTTP/$HVER 200"

new "PATCH ds/startup: 405, NETCONF cannot edit-config startup"
expectpart "$(curl $CURLOPTS -X PATCH -H "$JSON" $DS:startup/example:x/y=1 -d '{"example:y":[{"a":"1","z":{"b":"startup"}}]}')" 0 "HTTP/$HVER 405" "Allow: OPTIONS,HEAD,GET"

new "PATCH ds/running: 405"
expectpart "$(curl $CURLOPTS -X PATCH -H "$JSON" $DS:running/example:x/y=1 -d '{"example:y":[{"a":"1","z":{"b":"patched"}}]}')" 0 "HTTP/$HVER 405" "Allow: OPTIONS,HEAD,GET"

new "POST ds/running: 405"
expectpart "$(curl $CURLOPTS -X POST -H "$JSON" $DS:running/example:x -d '{"example:y":[{"a":"8"}]}')" 0 "HTTP/$HVER 405"

new "running unchanged by the rejected edits"
expectpart "$(curl $CURLOPTS -X GET $DS:running/example:x)" 0 "HTTP/$HVER 200" '"b":"one"' --not-- '"b":"patched"' '"a":"8"' '"b":"startup"'

new "startup unchanged by the rejected edit"
expectpart "$(curl $CURLOPTS -X GET $DS:startup/example:x/y=1/z/b)" 0 "HTTP/$HVER 200" '"example:b":"one"'

new "Default: PUT ds/candidate is auto-committed (RFC 8040 Sec 1.4)"
expectpart "$(curl $CURLOPTS -X PUT -H "$JSON" $DS:candidate/example:x/y=3 -d '{"example:y":[{"a":"3"}]}')" 0 "HTTP/$HVER 201"

new "y=3 is in running"
expectpart "$(curl $CURLOPTS -X GET $DS:running/example:x/y=3)" 0 "HTTP/$HVER 200"

new "GET ds/running depth=1 prunes all three y entries"
expectpart "$(curl $CURLOPTS -X GET "$DS:running?depth=1")" 0 "HTTP/$HVER 200" '"example:x"' --not-- '"a":"'

new "GET ds/operational includes config in use"
expectpart "$(curl $CURLOPTS -X GET $DS:operational/example:x)" 0 "HTTP/$HVER 200" '"a":"1"' '"a":"3"'

new "GET ds/operational includes state (yang-library)"
expectpart "$(curl $CURLOPTS -X GET $DS:operational/ietf-yang-library:yang-library)" 0 "HTTP/$HVER 200" '"module-set"'

new "GET ds/running has no state"
expectpart "$(curl $CURLOPTS -X GET $DS:running/ietf-yang-library:yang-library)" 0 "HTTP/$HVER 404"

new "HEAD ds/operational"
expectpart "$(curl $CURLOPTS -I $DS:operational/example:x)" 0 "HTTP/$HVER 200"

new "PUT ds/operational: 405"
expectpart "$(curl $CURLOPTS -X PUT -H "$JSON" $DS:operational/example:x/y=1 -d '{"example:y":[{"a":"1"}]}')" 0 "HTTP/$HVER 405" "Allow: OPTIONS,HEAD,GET"

new "POST ds/operational: 405"
expectpart "$(curl $CURLOPTS -X POST -H "$JSON" $DS:operational/example:x -d '{"example:y":[{"a":"8"}]}')" 0 "HTTP/$HVER 405"

stop

# --------------------------------------------------------------------
start ""

new "Without :startup, ds/startup is not a resource"
expectpart "$(curl $CURLOPTS -X GET $DS:startup)" 0 "HTTP/$HVER 400" "Unsupported datastore type"

stop

rm -rf $dir

new "endtest"
endtest
