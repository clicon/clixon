#!/usr/bin/env bash
# RESTCONF error-handling regression around api-path translation and error replies

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

mkdir -p /usr/local/var/example && chown clicon:clicon /usr/local/var/example

APPNAME=example
cfg=$dir/conf.xml
fyang=$dir/restconf-error.yang

# Define default restconf config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)
if [ $? -ne 0 ]; then
    err1 "Error when generating certs"
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang
module restconf-error{
   yang-version 1.1;
   namespace "urn:example:restconf-error";
   prefix re;
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

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend

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

new "baseline host-meta"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/.well-known/host-meta)" 0 "HTTP/$HVER 200"

new "baseline restconf data root"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 200"

new "malformed api-path stress should return http error and keep daemon alive"
for i in $(seq 1 25); do
    # Invalid restval on container
    resp="$(curl $CURLOPTS -X GET \
        $RCPROTO://localhost/restconf/data/restconf-error:table=x 2>/dev/null || true)"
    if [[ "$resp" != *"HTTP/"* ]]; then
        err "missing HTTP response on malformed api-path table=x"
    fi
    if [[ "$resp" != *" 400"* && "$resp" != *" 404"* && "$resp" != *" 412"* ]]; then
        err "unexpected status on malformed api-path table=x"
    fi

    # List key cardinality mismatch
    resp="$(curl $CURLOPTS -X GET \
        $RCPROTO://localhost/restconf/data/restconf-error:table/parameter=a,b 2>/dev/null || true)"
    if [[ "$resp" != *"HTTP/"* ]]; then
        err "missing HTTP response on malformed list key"
    fi
    if [[ "$resp" != *" 400"* && "$resp" != *" 404"* && "$resp" != *" 412"* ]]; then
        err "unexpected status on malformed list key"
    fi

    # Invalid method at same endpoint should still produce proper restconf error
    resp="$(curl $CURLOPTS -X XYS \
        $RCPROTO://localhost/restconf/data/restconf-error:table 2>/dev/null || true)"
    if [[ "$resp" != *"HTTP/"* ]]; then
        err "missing HTTP response on invalid method"
    fi
    if [[ "$resp" != *" 400"* && "$resp" != *" 404"* && "$resp" != *" 405"* ]]; then
        err "unexpected status on invalid method"
    fi

    # Ensure daemon remains healthy across repeated malformed requests.
    if [ $((i % 5)) -eq 0 ]; then
        expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/.well-known/host-meta)" 0 "HTTP/$HVER 200"
    fi
done

new "restconf data root still healthy after stress"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 200"

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

if [ $BE -ne 0 ]; then
    new "Kill backend"
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
