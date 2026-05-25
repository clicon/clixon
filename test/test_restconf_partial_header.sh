#!/usr/bin/env bash
# Restconf HTTP/1 partial-header handling (#667)
# Send a request whose headers are split across two TCP writes with a sleep
# between, simulating WAN fragmentation. The server must wait for the full
# header instead of returning 400 malformed-message. Also verify that
# non-HTTP traffic (TLS handshake bytes on an HTTP port) is still rejected
# immediately, and that a peer that stalls mid-header is closed by the
# header-timeout.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

if ! ${HAVE_HTTP1}; then
    echo "...skipped: Must run with http/1"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# Pin to http and http/1
RCPROTO=http
if [ ${HAVE_LIBNGHTTP2} = true ]; then
    HAVE_LIBNGHTTP2=false
    CURLOPTS=${CURLOPTS/http2/http1.1}
    HVER=1.1
fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/restconf.yang

RESTCONFIG=$(restconf_config none false)
if [ $? -ne 0 ]; then
    err1 "Error when generating certs"
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
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
   container top{
      leaf x{ type string; }
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

# Build a >2KB Authorization header to mimic a JWT and force header bytes
# beyond a single TCP segment boundary on most stacks.
big=$(head -c 2200 /dev/urandom | base64 -w0)

new "split header arrives across two writes - expect 200 not 400"
out=$(
{ printf 'GET /restconf HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer %s\r\n' "$big"
  sleep 0.3
  printf 'Accept: application/yang-data+xml\r\n\r\n'
} | timeout 5 nc -q 1 localhost 80
)
expectpart "$out" 0 "HTTP/1.1 200"

new "non-HTTP bytes on HTTP port - expect immediate 400, not stall"
out=$(printf '\x16\x03\x01\x00\x60\x01\x00\x00\x5c\x03\x03' | timeout 5 nc -q 1 localhost 80)
expectpart "$out" 0 "HTTP/1.1 400"

new "partial header that never completes - connection closed by timeout"
# Send a plausible method but never send \r\n\r\n. Server must close us
# within RESTCONF_HEADER_TIMEOUT_S (10s) rather than waiting forever.
t0=$(date +%s)
printf 'GET /restconf HTTP/1.1\r\nHost: localhost\r\n' | timeout 15 nc localhost 80 >/dev/null
t1=$(date +%s)
elapsed=$((t1 - t0))
if [ $elapsed -ge 15 ]; then
    err1 "header timeout did not fire within 15s (elapsed=$elapsed)"
fi
if [ $elapsed -lt 2 ]; then
    err1 "connection closed too quickly (elapsed=${elapsed}s); timeout may not have engaged"
fi

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
