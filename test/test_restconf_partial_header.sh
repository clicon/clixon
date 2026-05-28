#!/usr/bin/env bash
# Restconf HTTP/1 partial-header handling (#667)
# Send a request whose headers are split across two TCP writes with a sleep
# between, simulating WAN fragmentation. The server must wait for the full
# header instead of returning 400 malformed-message. Also verify that
# non-HTTP traffic (TLS handshake bytes on an HTTP port) is still rejected
# immediately, and that a peer that stalls mid-header is closed by the
# header-timeout.
#
# Raw socket interaction is done via expect/Tcl rather than nc - clixon
# tests already use expect (see test_pagination_expect.exp) and Tcl's
# built-in socket gives us deterministic split-write semantics that no
# nc/netcat variant offers portably.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

if ! ${HAVE_HTTP1}; then
    echo "...skipped: Must run with http/1"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

if ! command -v expect >/dev/null 2>&1; then
    echo "...skipped: expect not installed"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

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

# Tcl helper: connect to localhost:80, write $1, sleep ms $2, write $3,
# read response (up to 5s), print response on stdout. expect chosen over
# nc/netcat to avoid -q/-N/-w portability differences.
function tcl_split_send()
{
    local p1="$1" delay_ms="$2" p2="$3"
    expect <<EOF
log_user 0
set sock [socket localhost 80]
fconfigure \$sock -translation binary -buffering none -blocking 0
puts -nonewline \$sock "$p1"
flush \$sock
after $delay_ms
puts -nonewline \$sock "$p2"
flush \$sock
set resp ""
set deadline [expr {[clock milliseconds] + 5000}]
while {[clock milliseconds] < \$deadline} {
    set chunk [read \$sock]
    if {[string length \$chunk] > 0} {
        append resp \$chunk
        if {[string match "*HTTP/1.1*\r\n*" \$resp]} { break }
    }
    after 50
}
close \$sock
puts -nonewline \$resp
EOF
}

# Build a >2KB Authorization header that will not fit in a single MSS.
big=$(head -c 2200 /dev/urandom | base64 | tr -d '\n')

new "split header arrives across two writes - expect 200 not 400"
part1="GET /restconf HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer $big\r\n"
part2="Accept: application/yang-data+xml\r\n\r\n"
out=$(tcl_split_send "$part1" 300 "$part2")
expectpart "$out" 0 "HTTP/1.1 200"

new "non-HTTP bytes on HTTP port - expect 400, not stall"
# TLS ClientHello magic - first byte 0x16, no method, no CRLF
out=$(expect <<'EOF'
log_user 0
set sock [socket localhost 80]
fconfigure $sock -translation binary -buffering none -blocking 0
puts -nonewline $sock "\x16\x03\x01\x00\x60\x01\x00\x00\x5c\x03\x03"
flush $sock
set resp ""
set deadline [expr {[clock milliseconds] + 5000}]
while {[clock milliseconds] < $deadline} {
    set chunk [read $sock]
    if {[string length $chunk] > 0} {
        append resp $chunk
        if {[string match "*HTTP/1.1*\r\n*" $resp]} { break }
    }
    after 50
}
close $sock
puts -nonewline $resp
EOF
)
expectpart "$out" 0 "HTTP/1.1 400"

new "partial header that never completes - server closes within timeout"
# Send the request line + one header, then hold the socket without sending
# the final \r\n. The header-timeout (RESTCONF_HEADER_TIMEOUT_S = 10s) must
# close us between 2 and 20 seconds.
#
# Time the close from bash, not from Tcl: Tcl's close on a non-blocking
# socket whose peer just FIN'd can raise, terminating the script before any
# puts reaches stdout (observed on alpine). The Tcl side just waits.
t0=$(date +%s)
expect <<'EOF' >/dev/null
log_user 0
if {[catch {socket localhost 80} sock]} { exit 0 }
fconfigure $sock -translation binary -buffering none -blocking 0
puts -nonewline $sock "GET /restconf HTTP/1.1\r\nHost: localhost\r\n"
flush $sock
set deadline [expr {[clock milliseconds] + 20000}]
while {[clock milliseconds] < $deadline} {
    if {[catch {read $sock}]} { break }
    if {[eof $sock]} { break }
    after 100
}
catch {close $sock}
EOF
t1=$(date +%s)
elapsed=$((t1 - t0))
if [ "$elapsed" -ge 20 ]; then
    err1 "server did not close stalled connection within 20s (elapsed=${elapsed}s)"
fi
if [ "$elapsed" -lt 2 ]; then
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
