#!/usr/bin/env bash
# Restconf HTTP/1 partial-header handling (#667)
# Send a request whose headers are split across two TCP writes with a sleep
# between, simulating WAN fragmentation. The server must wait for the full
# header instead of returning 400 malformed-message. Also verify that
# non-HTTP traffic (TLS handshake bytes on an HTTP port) is still rejected
# immediately, and that a peer that stalls mid-header is closed by the
# header-timeout.
#
# Uses bash /dev/tcp redirection rather than nc/netcat to avoid the
# portability issues called out in lib.sh (BSD nc vs GNU netcat vs ncat vs
# busybox nc all differ on -q/-N/-w).

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

if ! ${HAVE_HTTP1}; then
    echo "...skipped: Must run with http/1"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# This test uses bash /dev/tcp redirections (already relied on by
# wait_grpc in lib.sh). If the local bash was built without
# --enable-net-redirections the test will fail loudly rather than skip.

# Pin to http and http/1 to keep the raw protocol bytes simple
RCPROTO=http
if [ ${HAVE_LIBNGHTTP2} = true ]; then
    HAVE_LIBNGHTTP2=false
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

# Send two halves of an HTTP request via bash /dev/tcp with a sleep between.
# Args: $1 first half, $2 second half, $3 sleep seconds; prints response on stdout.
function split_send()
{
    local p1="$1" p2="$2" delay="$3" line resp=""
    exec 3<>/dev/tcp/localhost/80
    printf '%s' "$p1" >&3
    sleep "$delay"
    printf '%s' "$p2" >&3
    while IFS= read -r -t 5 line <&3; do
        resp="${resp}${line}"$'\n'
    done
    exec 3<&-
    printf '%s' "$resp"
}

# Build a >2KB Authorization header (base64 of 2200 random bytes -> ~2933 chars)
big=$(head -c 2200 /dev/urandom | base64 | tr -d '\n')

new "split header arrives across two writes - expect 200 not 400"
part1=$(printf 'GET /restconf HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer %s\r\n' "$big")
part2=$(printf 'Accept: application/yang-data+xml\r\n\r\n')
out=$(split_send "$part1" "$part2" 0.3)
expectpart "$out" 0 "HTTP/1.1 200"

new "non-HTTP bytes on HTTP port - expect 400, not stall"
exec 3<>/dev/tcp/localhost/80
printf '\x16\x03\x01\x00\x60\x01\x00\x00\x5c\x03\x03' >&3
resp=""
while IFS= read -r -t 5 line <&3; do
    resp="${resp}${line}"$'\n'
done
exec 3<&-
expectpart "$resp" 0 "HTTP/1.1 400"

new "partial header that never completes - server closes within timeout"
t0=$(date +%s)
exec 3<>/dev/tcp/localhost/80
printf 'GET /restconf HTTP/1.1\r\nHost: localhost\r\n' >&3
# Block until server closes the socket (returns EOF), bounded by read -t
while IFS= read -r -t 20 line <&3; do : ; done
exec 3<&-
t1=$(date +%s)
elapsed=$((t1 - t0))
if [ $elapsed -ge 20 ]; then
    err1 "server did not close stalled connection within 20s (elapsed=${elapsed}s)"
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
