#!/usr/bin/env bash
#
# Special test for plain(non-tls) upgrade of http/1 to http/2
# Only native
# Three cases controlled by compile-time #ifdef:s
# http/1-only
# http/2-only
# http/1 + http/2

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Only works with native
if [ "${WITH_RESTCONF}" != "native" ]; then
    if [ "$s" = $0 ]; then exit 0; else return 0; fi # skip
fi

# Cant make it work in sum.sh...
if ! ${HAVE_LIBEVHTP}; then
    echo "...skipped: LIBEVHTP is false, must run with http/1 (evhtp)"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

APPNAME=example

cfg=$dir/conf.xml

RCPROTO=http
RESTCONFIG=$(restconf_config none false)

# Clixon config
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_BACKEND_RESTCONF_PROCESS>false</CLICON_BACKEND_RESTCONF_PROCESS>
  <CLICON_RESTCONF_HTTP2_PLAIN>true</CLICON_RESTCONF_HTTP2_PLAIN>
  $RESTCONFIG <!-- only fcgi -->
</clixon-config>
EOF


# Restconf test routine with arguments:
# 1. Enable http for http/2 (CLICON_RESTCONF_HTTP2_PLAIN)
# 2. Expected http return value
function testrun()
{
    h2enable=$1

    new "test params: -f $cfg -- -s"
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

	new "start restconf daemon -o CLICON_RESTCONF_HTTP2_PLAIN=${h2enable}"
	start_restconf -f $cfg -o CLICON_RESTCONF_HTTP2_PLAIN=${h2enable}
    fi



    if [ ${HAVE_LIBNGHTTP2} = false -a ${HAVE_LIBEVHTP} = true ]; then    # http/1 only

	new "wait restconf"
	wait_restconf

	# http/1-only always stays on http/1 in http/1 + http/2 mode
	new "restconf http1.1 no upgrade (h2:$h2enable)"
	echo "curl -Ssik --http1.1 -X GET http://localhost/.well-known/host-meta"
	expectpart "$(curl -Ssik --http1.1 -X GET http://localhost/.well-known/host-meta)" 0 "HTTP/1.1 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>" --not-- "HTTP/2"
	
	# http/1->http/2 switched if h2enable, otherwise it stays in http/1
	new "restconf upgrade http1->http2 (h2:$h2enable)"
	echo "curl -Ssik --http2 -X GET http://localhost/.well-known/host-meta"
	# stay on http/1
	expectpart "$(curl -Ssik --http2 -X GET http://localhost/.well-known/host-meta)" 0 "HTTP/1.1 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"  --not-- "HTTP/2"

	# http/2-only is always an error in http/1 + http/2 mode
	new "restconf http2 prior-knowledge (h2:$h2enable)"
	echo "curl -Ssik --http2-prior-knowledge -X GET http://localhost/.well-known/host-meta"
	expectpart "$(curl -Ssik --http2-prior-knowledge -X GET http://localhost/.well-known/host-meta 2>&1)" "16 52 55"

    elif [ ${HAVE_LIBNGHTTP2} = true -a ${HAVE_LIBEVHTP} = false ]; then  # http/2 only

	sleep 2 # Cannot do wait restconf
	
	# http/1-only always stays on http/1 in http/1 + http/2 mode
	new "restconf http1.1 no upgrade (h2:$h2enable)"
	echo "curl -Ssik --http1.1 -X GET http://localhost/.well-known/host-meta"
	# XXX cannot use expectpart due to null in pipe
	curl -Ssik --http1.1 -X GET http://localhost/.well-known/host-meta
	if [ $? == 0 ]; then
	    err "NULL" "sucess"
	fi

	# http/1->http/2 switched if h2enable, otherwise it stays in http/1
	new "restconf upgrade http1->http2 (h2:$h2enable)"
	echo "curl -Ssik --http2 -X GET http://localhost/.well-known/host-meta"
	# stay on http/1
	curl -Ssik --http2 -X GET http://localhost/.well-known/host-meta
	if [ $? == 0 ]; then
	    err "NULL" "sucess"
	fi

	# http/2-only is always an error in http/1 + http/2 mode
	new "restconf http2 prior-knowledge (h2:$h2enable)"
	echo "curl -Ssik --http2-prior-knowledge -X GET http://localhost/.well-known/host-meta"
	if $h2enable; then
	    new "wait restconf"
	    wait_restconf

	    expectpart "$(curl -Ssik --http2-prior-knowledge -X GET http://localhost/.well-known/host-meta 2>&1)" 0 "HTTP/2 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>" --not-- "HTTP/1.1"

	else
	    expectpart "$(curl -Ssik --http2-prior-knowledge -X GET http://localhost/.well-known/host-meta 2>&1)" 0 "HTTP/2 405"
	fi

    elif [ ${HAVE_LIBNGHTTP2} = true -a ${HAVE_LIBEVHTP} = true ]; then  # http/1 + http/2

	new "wait restconf"
	wait_restconf
	
	# http/1-only always stays on http/1 in http/1 + http/2 mode
	new "restconf http1.1 no upgrade (h2:$h2enable)"
	echo "curl -Ssik --http1.1 -X GET http://localhost/.well-known/host-meta"
	expectpart "$(curl -Ssik --http1.1 -X GET http://localhost/.well-known/host-meta)" 0 "HTTP/1.1 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>" --not-- "HTTP/2"
	
	# http/1->http/2 switched if h2enable, otherwise it stays in http/1
	new "restconf upgrade http1->http2 (h2:$h2enable)"
	echo "curl -Ssik --http2 -X GET http://localhost/.well-known/host-meta"
	if $h2enable; then
	    # switch to http/2
	    expectpart "$(curl -Ssik --http2 -X GET http://localhost/.well-known/host-meta)" 0 "HTTP/2 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"  "HTTP/1.1 101 Switching" "HTTP/2 200" --not-- "HTTP/1.1 200"
	else
	    # stay on http/1
	    expectpart "$(curl -Ssik --http2 -X GET http://localhost/.well-known/host-meta)" 0 "HTTP/1.1 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"  --not-- "HTTP/2"
	fi

	# http/2-only is always an error in http/1 + http/2 mode
	new "restconf http2 prior-knowledge (h2:$h2enable)"
	echo "curl -Ssik --http2-prior-knowledge -X GET http://localhost/.well-known/host-meta"
	expectpart "$(curl -Ssik --http2-prior-knowledge -X GET http://localhost/.well-known/host-meta 2>&1)" "16 52 55"

    fi

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
}

new "disable plain http/2"
testrun false

new "enable plain http/2"
testrun true

# Set by restconf_config
unset RESTCONFIG
unset RCPROTO

rm -rf $dir

new "endtest"
endtest
