#!/usr/bin/env bash
# Regression test for RESTCONF native double-free close paths

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# The fix is in native RESTCONF connection/stream teardown.
if [ "${WITH_RESTCONF}" != "native" ]; then
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

mkdir -p /usr/local/var/example && chown clicon:clicon /usr/local/var/example

APPNAME=example
cfg=$dir/conf.xml
fyang=$dir/restconf.yang

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

new "stress repeated close/error paths"
for i in $(seq 1 40); do
    # Trigger protocol mismatch close path.
    if [ "$RCPROTO" = "https" ]; then
        curl $CURLOPTS -X GET http://localhost:443/.well-known/host-meta >/dev/null 2>&1 || true
    else
        curl $CURLOPTS -X GET https://localhost:80/.well-known/host-meta >/dev/null 2>&1 || true
    fi

    # Trigger malformed/method error handling path.
    curl $CURLOPTS -X XYS -H 'Accept: application/yang-data+json' \
        $RCPROTO://localhost/restconf/data/example:table >/dev/null 2>&1 || true

    # Exercise http/2 path when available.
    if ${HAVE_LIBNGHTTP2}; then
        curl $CURLOPTS --http2-prior-knowledge -X GET \
            $RCPROTO://localhost/.well-known/host-meta >/dev/null 2>&1 || true
    fi

    # Optional raw malformed request over plaintext HTTP.
    if [ "$RCPROTO" = "http" -a -n "$netcat" ]; then
        ${netcat} 127.0.0.1 80 <<EOF >/dev/null 2>&1
GET /restconf/data HTTP/a.1
Host: localhost

EOF
    fi

    # Verify daemon survives repeated close/error sequences.
    if [ $((i % 10)) -eq 0 ]; then
        hdr=$(curl $CURLOPTS -X GET $RCPROTO://localhost/.well-known/host-meta 2>/dev/null)
        if [[ "$hdr" != *"HTTP/"* || "$hdr" != *"200"* ]]; then
            err "restconf became unhealthy after close-path stress"
        fi
        pid=$(pgrep -f clixon_restconf)
        if [ -z "$pid" ]; then
            err "restconf process died during close-path stress"
        fi
    fi
done

new "host-meta after stress"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/.well-known/host-meta)" 0 "HTTP/$HVER 200"

new "restconf data endpoint after stress"
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
