#!/usr/bin/env bash
# Restconf basic functionality also uri encoding using eth/0/0
# Note there are many variants: (1)fcgi/native, (2) http/https, (3) IPv4/IPv6, (4)local or backend-config
# (1) fcgi/native
# This is compile-time --with-restconf=fcgi or native, so either or
# - fcgi: Assume http server setup, such as nginx described in apps/restconf/README.md
# - native: test both local config and get config from backend 
# (2) http/https
# - fcgi: relies on nginx has https setup
# - native: generate self-signed server certs 
# (3) IPv4/IPv6 (only loopback 127.0.0.1 / ::1)
# - The tests runs through both
# - IPv6 by default disabled since docker does not support it out-of-the box
# (4) local/backend config. Native only
# - The tests runs through both (if compiled with native)
# See also test_restconf_op.sh
# See test_restconf_rpc.sh for cases when CLICON_BACKEND_RESTCONF_PROCESS is set
#
# Note, for tests: "Wrong proto=http on https port, expect bad reques"
# there was an effort to return an HTTP error on HTTPS socket, but it breaks other
# error cases, more stable is to just close the socket, but
# curl gets an error code instead.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/clixon-example.yang

# clixon-restconf is used in the test, need local copy
# This is a kludge: look in src otherwise assume it is installed in /usr/local/share
# Note that revisions may change and may need to be updated
y=clixon-restconf@${CLIXON_RESTCONF_REV}.yang
if [ -d ${TOP_SRCDIR}/yang/clixon ]; then 
    cp ${TOP_SRCDIR}/yang/clixon/$y $dir/
else
    cp /usr/local/share/clixon/$y $dir/
fi

if [ "${WITH_RESTCONF}" = "native" ]; then
    # Create server certs
    certdir=$dir/certs
    srvkey=$certdir/srv_key.pem
    srvcert=$certdir/srv_cert.pem
    cakey=$certdir/ca_key.pem # needed?
    cacert=$certdir/ca_cert.pem
    test -d $certdir || mkdir $certdir
    # Create server certs and CA
    cacerts $cakey $cacert
    servercerts $cakey $cacert $srvkey $srvcert
else
    # Define default restconfig config: RESTCONFIG
    RESTCONFIG=$(restconf_config none false)
fi

# This is a fixed 'state' implemented in routing_backend. It is assumed to be always there
state='{"clixon-example:state":{"op":\["41","42","43"\]}'

if $IPv6; then
    # For backend config, create 4 sockets, all combinations IPv4/IPv6 + http/https
    RESTCONFIG1=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <enable>true</enable>
   <auth-type>none</auth-type>
   <server-cert-path>$srvcert</server-cert-path>
   <server-key-path>$srvkey</server-key-path>
   <server-ca-cert-path>$cakey</server-ca-cert-path>
   <pretty>false</pretty>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>443</port><ssl>true</ssl></socket>
   <socket><namespace>default</namespace><address>::</address><port>80</port><ssl>false</ssl></socket>
   <socket><namespace>default</namespace><address>::</address><port>443</port><ssl>true</ssl></socket>
</restconf>
EOF
)
else
       # For backend config, create 2 sockets, all combinations IPv4 + http/https
    RESTCONFIG1=$(cat <<EOF
<restconf xmlns="http://clicon.org/restconf">
   <enable>true</enable>
   <auth-type>none</auth-type>
   <server-cert-path>$srvcert</server-cert-path>
   <server-key-path>$srvkey</server-key-path>
   <server-ca-cert-path>$cakey</server-ca-cert-path>
   <pretty>false</pretty>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>80</port><ssl>false</ssl></socket>
   <socket><namespace>default</namespace><address>0.0.0.0</address><port>443</port><ssl>true</ssl></socket>
</restconf>
EOF
)
fi

# Clixon config
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
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
  $RESTCONFIG <!-- only fcgi -->
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    import ietf-interfaces { 
        /* is in yang/optional which means clixon must be installed using --opt-yang-installdir */
        prefix if;
    }
    import ietf-ip {
        prefix ip;
    }
    import iana-if-type {
        prefix ianaift;
    }
    import ietf-datastores {
        prefix ds;
    }
    import clixon-autocli{
        prefix autocli;
    }
    description
        "Clixon example used as a part of the Clixon test suite.
         It can be used as a basis for making new Clixon applications.
         Note, may change without updating revision, just for testing current master.
         ";
    /* Example interface type for tests, local callbacks, etc */
    identity eth {
        base if:interface-type;
    }
    identity loopback {
        base if:interface-type;
    }
    /* Generic config data */
    container table{
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
            leaf hidden{
                type string;
                autocli:hide;
            }
            leaf stat{
                description "Inline state data for example application";
                config false;
                type int32;
            }
        }
    }
    /* State data (not config) for the example application*/
    container state {
        config false;
        description "state data for the example application (must be here for example get operation)";
        leaf-list op {
            type string;
        }
    }
    augment "/if:interfaces/if:interface" {
        container my-status {
            config false;
            description "For testing augment+state";
            leaf int {
                type int32;
            }
            leaf str {
                type string;
            }
        }
    }
    /* yang extension implemented by the example backend code. */
    extension e4 {
        description
            "The first child of the ex:e4 (unknown) statement is inserted into 
            the module as a regular data statement. This means that 'uses bar;'
            in the ex:e4 statement below is a valid data node";
        argument arg;
    }
    grouping bar {
        leaf bar{
            type string;
        }
    }
    ex:e4 arg1{
        uses bar;
    }
    rpc client-rpc {
        description "Example local client-side RPC that is processed by the
                     the netconf/restconf and not sent to the backend.
                     This is a clixon implementation detail: some rpc:s
                     are better processed by the client for API or perf reasons";
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
    rpc empty {
        description "Smallest possible RPC with no input or output sections";
    }
    rpc example {
        description "Some example input/output for testing RFC7950 7.14.
                     RPC simply echoes the input for debugging.";
        input {
            leaf x {
                description
                    "If a leaf in the input tree has a 'mandatory' statement with
                   the value 'true', the leaf MUST be present in an RPC invocation.";
                type string;
                mandatory true;
            }
            leaf y {
                description
                    "If a leaf in the input tree has a 'mandatory' statement with the
                  value 'true', the leaf MUST be present in an RPC invocation.";
                type string;
                default "42";
            }
        }
        output {
            leaf x {
                type string;
            }
            leaf y {
                type string;
            }
         }
   }
}
EOF

# Restconf test routine with arguments:
# 1. proto:http/https
# 2: addr: 127.0.0.1/::1 # IPv4 or IPv6
function testrun()
{
    proto=$1  # http/https
    addr=$2   # 127.0.0.1/::1

    RCPROTO=$proto # for start/wait of restconf
    echo "proto:$proto"
    echo "addr:$addr"

    new "test params: -f $cfg -- -s"
    if [ $BE -ne 0 ]; then
        new "kill old backend"
        sudo clixon_backend -zf $cfg
        if [ $? -ne 0 ]; then
            err
        fi
        sudo pkill -f clixon_backend # to be sure

        new "start backend -s init -f $cfg -- -s"
        start_backend -s init -f $cfg -- -s
    fi

    new "wait backend"
    wait_backend

    new "netconf edit config"
    expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RESTCONFIG1</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf commit"
    expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    if [ $RC -ne 0 ]; then
        new "kill old restconf daemon"
        stop_restconf_pre

        new "start restconf daemon"
        # inline of start_restconf, cant make quotes to work
        echo "sudo -u $wwwstartuser -s $clixon_restconf $RCLOG -D $DBG -f $cfg -R $RESTCONFIG1"
        sudo -u $wwwstartuser -s $clixon_restconf $RCLOG -D $DBG -f $cfg -R "$RESTCONFIG1" </dev/null &>/dev/null &
        if [ $? -ne 0 ]; then
            err1 "expected 0" "$?"
        fi
    fi

    #------------------------------------------------------- HTTP/1 + HTTP/2 
    if [ ${HAVE_LIBNGHTTP2} = true -a ${HAVE_HTTP1} = true ]; then

        if [ $proto = http ]; then # No plain http/2
            HVER=1.1
        else
            HVER=2
        fi
        new "wait restconf"
        wait_restconf
    
        new "restconf root discovery. RFC 8040 3.1 (xml+xrd)"
        echo "curl $CURLOPTS -X GET $proto://$addr/.well-known/host-meta"
        expectpart "$(curl $CURLOPTS -X GET $proto://$addr/.well-known/host-meta)" 0 "HTTP/$HVER 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"

        echo "fcgi or native+http/1 or native+http/1+http/2"
        if [ "${WITH_RESTCONF}" = "native" ]; then # XXX does not work with nginx
            new "restconf GET http/1.0  - returns 1.0"
            expectpart "$(curl $CURLOPTS --http1.0 -X GET $proto://$addr/.well-known/host-meta)" 0 'HTTP/1.0 200 OK' "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"
        fi 
        new "restconf GET http/1.1"
        expectpart "$(curl $CURLOPTS --http1.1 -X GET $proto://$addr/.well-known/host-meta)" 0 'HTTP/1.1 200 OK' "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"

        new "restconf GET http/2 switch protocol"
        if [ $proto = http ]; then # see (2) https to http port in restconf_main_native.c
            expectpart "$(curl $CURLOPTS --http2 -X GET $proto://$addr/.well-known/host-meta)" 0 "" "HTTP/1.1 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"
        else
            expectpart "$(curl $CURLOPTS --http2 -X GET $proto://$addr/.well-known/host-meta)" 0 "" "HTTP/2 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"       # Only if https:  HTTP/1.1 101 Switching Protocols
        fi

        # http2-prior knowledge
        if [ $proto = http ]; then # see (2) https to http port in restconf_main_native.c
            new "restconf GET http/2 prior-knowledge (http)"
            expectpart "$(curl $CURLOPTS --http2-prior-knowledge -X GET $proto://$addr/.well-known/host-meta 2>&1)" "16 52 55" # "Error in the HTTP2 framing layer" "Connection reset by peer"
        else
            new "restconf GET https/2 prior-knowledge"
            expectpart "$(curl $CURLOPTS --http2-prior-knowledge -X GET $proto://$addr/.well-known/host-meta)" 0 "HTTP/$HVER 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"
        fi
        
        # Wrong protocol http when https or vice versa
        if [ $proto = http ]; then # see (2) https to http port in restconf_main_native.c
            new "Wrong proto=https on http port, expect err 35 wrong version number"
            expectpart "$(curl $CURLOPTS -X GET https://$addr:80/.well-known/host-meta 2>&1)" 35 #"wrong version number" # dependent on curl version
        else # see (1) http to https port in restconf_main_native.c
            new "Wrong proto=http on https port, expect bad request http1+2"
#           expectpart "$(curl $CURLOPTS -X GET http://$addr:443/.well-known/host-meta 2>&1)" 56 "Connection reset by peer"
            expectpart "$(curl $CURLOPTS -X GET http://$addr:443/.well-known/host-meta)" 0 "HTTP/" "400"

        fi
        
    #------------------------------------------------------- HTTP/2 ONLY
    elif [ ${HAVE_LIBNGHTTP2} = true -a ${HAVE_HTTP1} = false ]; then
        HVER=2
        
        new "wait restconf"
        wait_restconf

        new "restconf root discovery. RFC 8040 3.1 (xml+xrd)"
        echo "curl $CURLOPTS -X GET $proto://$addr/.well-known/host-meta"
        expectpart "$(curl $CURLOPTS -X GET $proto://$addr/.well-known/host-meta)" 0 "HTTP/$HVER 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"

        echo "native + http/2 only"
        # Important here is robustness of restconf daemon, not a meaningful reply
        if [ $proto = http ]; then # see (2) https to http port in restconf_main_native.c
            # http protocol mismatch can just close the socket if assumed its http/2
            # everything else would guess it is http/1 which is really wrong here
            # The tr statement replaces null char to get rid of annoying message:
            # ./test_restconf.sh: line 180: warning: command substitution: ignored null byte in input
            new "restconf GET http/1.0  - close"
            expectpart "$(curl $CURLOPTS --http1.0 -X GET $proto://$addr/.well-known/host-meta | tr '\0' '\n')" 0 "" --not-- 'HTTP'
        else
            new "restconf GET https/1.0  - close"
            expectpart "$(curl $CURLOPTS --http1.0 -X GET $proto://$addr/.well-known/host-meta)" "52 56" "" --not-- 'HTTP'

        fi

        if [ $proto = http ]; then
            new "restconf GET http/1.1 - close"
            expectpart "$(curl $CURLOPTS --http1.1 -X GET $proto://$addr/.well-known/host-meta | tr '\0' '\n')" 0 --not-- 'HTTP'
        else
            new "restconf GET https/1.1 - close"
            expectpart "$(curl $CURLOPTS --http1.1 -X GET $proto://$addr/.well-known/host-meta)" "52 56" --not-- 'HTTP'
        fi
        
        if [ $proto = http ]; then
            new "restconf GET http/2 switch protocol"
            expectpart "$(curl $CURLOPTS --http2 -X GET $proto://$addr/.well-known/host-meta | tr '\0' '\n')" 0 --not-- 'HTTP'
        else
            new "restconf GET https/2 alpn protocol"
            expectpart "$(curl $CURLOPTS --http2 -X GET $proto://$addr/.well-known/host-meta)" 0 "HTTP/$HVER 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"
        fi

        # Wrong protocol http when https or vice versa
        if [ $proto = http ]; then # see (2) https to http port in restconf_main_native.c
            new "Wrong proto=https on http port, expect err 35 wrong version number"
            expectpart "$(curl $CURLOPTS -X GET https://$addr:80/.well-known/host-meta 2>&1)" 35 #"wrong version number" # dependent on curl version
        else # see (1) http to https port in restconf_main_native.c
            new "Wrong proto=http on https port, expect bad request http2-only"
            expectpart "$(curl $CURLOPTS -X GET http://$addr:443/.well-known/host-meta)" "16 52 55 56" --not-- 'HTTP'
        fi

    else #------------------------------------------------------- HTTP/1 only

        HVER=1.1

        new "wait restconf"
        wait_restconf
    
        new "restconf root discovery. RFC 8040 3.1 (xml+xrd)"
        echo "curl $CURLOPTS -X GET $proto://$addr/.well-known/host-meta"
        expectpart "$(curl $CURLOPTS -X GET $proto://$addr/.well-known/host-meta)" 0 "HTTP/$HVER 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"

        echo "fcgi or native+http/1 or native+http/1+http/2"
        if [ "${WITH_RESTCONF}" = "native" ]; then # XXX does not work with nginx
            new "restconf GET http/1.0  - returns 1.0"
            expectpart "$(curl $CURLOPTS --http1.0 -X GET $proto://$addr/.well-known/host-meta)" 0 'HTTP/1.0 200 OK' "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"
        fi 
        new "restconf GET http/1.1"
        expectpart "$(curl $CURLOPTS --http1.1 -X GET $proto://$addr/.well-known/host-meta)" 0 'HTTP/1.1 200 OK' "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"

        # http/1 only Try http/2 - go back to http/1.1
        new "restconf GET http/2 switch protocol"
        expectpart "$(curl $CURLOPTS --http2 -X GET $proto://$addr/.well-known/host-meta)" 0 "HTTP/1.1 200 OK" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"         
        
        # http2-prior knowledge
        if [ $proto = http ]; then # see (2) https to http port in restconf_main_native.c
            new "restconf GET http/2 prior-knowledge (http)"
            expectpart "$(curl $CURLOPTS --http2-prior-knowledge -X GET $proto://$addr/.well-known/host-meta 2>&1)" "16 52 55" # "Error in the HTTP2 framing layer" "Connection reset by peer"
        else
            new "restconf GET https/2 prior-knowledge"
            expectpart "$(curl $CURLOPTS --http2-prior-knowledge -X GET $proto://$addr/.well-known/host-meta)" 0 "HTTP/$HVER 200" "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>" "<Link rel='restconf' href='/restconf'/>" "</XRD>"
        fi
        
        # Wrong protocol http when https or vice versa
        if [ $proto = http ]; then # see (2) https to http port in restconf_main_native.c
            new "Wrong proto=https on http port, expect err 35 wrong version number"
            expectpart "$(curl $CURLOPTS -X GET https://$addr:80/.well-known/host-meta 2>&1)" 35 #"wrong version number" # dependent on curl version
        else # see (1) http to https port in restconf_main_native.c
            new "Wrong proto=http on https port, expect bad request http/1 only"
#           expectpart "$(curl $CURLOPTS -X GET http://$addr:443/.well-known/host-meta 2>&1)" 56 "Connection reset by peer"
            expectpart "$(curl $CURLOPTS -X GET http://$addr:443/.well-known/host-meta)" 0 "HTTP/" "400"
        fi
    fi # HTTP/2    

    # Exact match
    new "restconf get restconf resource. RFC 8040 3.3 (json)"
    expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+json" $proto://$addr/restconf)" 0 "HTTP/$HVER 200" '{"ietf-restconf:restconf":{"data":{},"operations":{},"yang-library-version":"2019-01-04"}}'

    new "restconf get restconf resource. RFC 8040 3.3 (xml)"
    # Get XML instead of JSON?
    expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $proto://$addr/restconf)" 0 "HTTP/$HVER 200" '<restconf xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><data/><operations/><yang-library-version>2019-01-04</yang-library-version></restconf>'

    # Should be alphabetically ordered
    new "restconf get restconf/operations. RFC8040 3.3.2 (json)"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/operations)" 0 "HTTP/$HVER 200" '{"operations":{' '"clixon-example:empty":\[null\]' '"clixon-lib:debug":\[null\],"clixon-lib:ping":\[null\],"clixon-lib:stats":\[null\],"clixon-lib:restart-plugin":\[null\]' '"ietf-netconf:get-config":\[null\],"ietf-netconf:edit-config":\[null\],"ietf-netconf:copy-config":\[null\],"ietf-netconf:delete-config":\[null\],"ietf-netconf:lock":\[null\],"ietf-netconf:unlock":\[null\],"ietf-netconf:get":\[null\],"ietf-netconf:close-session":\[null\],"ietf-netconf:kill-session":\[null\],"ietf-netconf:commit":\[null\],"ietf-netconf:discard-changes":\[null\],"ietf-netconf:validate":\[null\]'

    new "restconf get restconf/operations. RFC8040 3.3.2 (xml)"
    ret=$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $proto://$addr/restconf/operations)
    expect='<operations><client-rpc xmlns="urn:example:clixon"/><empty xmlns="urn:example:clixon"/>'
    match=`echo $ret | grep --null -Eo "$expect"`
    if [ -z "$match" ]; then
        err "$expect" "$ret"
    fi

    new "restconf get restconf/yang-library-version. RFC8040 3.3.3"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/yang-library-version)" 0 "HTTP/$HVER 200" '{"ietf-restconf:yang-library-version":"2019-01-04"}'

    new "restconf get restconf/yang-library-version. RFC8040 3.3.3 (xml)"
    ret=$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $proto://$addr/restconf/yang-library-version)
    expect="<yang-library-version>2019-01-04</yang-library-version>"
    match=`echo $ret | grep --null -Eo "$expect"`
    if [ -z "$match" ]; then
        err "$expect" "$ret"
    fi

    new "restconf schema resource, RFC 8040 sec 3.7 according to RFC 8525 (explicit resource)"
    expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $proto://$addr/restconf/data/ietf-yang-library:yang-library/module-set=default/module=ietf-interfaces)" 0 "HTTP/$HVER 200" '{"ietf-yang-library:module":\[{"name":"ietf-interfaces","revision":"2018-02-20","namespace":"urn:ietf:params:xml:ns:yang:ietf-interfaces"}\]}'

    new "restconf schema resource, mod-state top-level"
    expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $proto://$addr/restconf/data/ietf-yang-library:yang-library/module-set=default)" 0 "HTTP/$HVER 200" "{\"ietf-yang-library:module-set\":\[{\"name\":\"default\",\"module\":\[{\"name\":\"clixon-autocli\",\"revision\":\"${CLIXON_AUTOCLI_REV}\",\"namespace\":\"http://clicon.org/autocli\"}" "{\"name\":\"clixon-lib\",\"revision\":\"${CLIXON_LIB_REV}\",\""

    new "restconf options. RFC 8040 4.1"
    expectpart "$(curl $CURLOPTS -X OPTIONS $proto://$addr/restconf/data)" 0 "HTTP/$HVER 200" "Allow: OPTIONS,HEAD,GET,POST,PUT,PATCH,DELETE"

    new "restconf HEAD. RFC 8040 4.2"
    expectpart "$(curl $CURLOPTS --head -H "Accept: application/yang-data+json" $proto://$addr/restconf/data)" 0 "HTTP/$HVER 200" "Content-Type: application/yang-data+json"

    new "restconf empty rpc JSON"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d {\"clixon-example:input\":null} $proto://$addr/restconf/operations/clixon-example:empty)" 0  "HTTP/$HVER 204"

    new "restconf empty rpc XML"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" -d '<input xmlns="urn:example:clixon"></input>' $proto://$addr/restconf/operations/clixon-example:empty)" 0  "HTTP/$HVER 204"

    new "restconf empty rpc, default media type should fail"
    expectpart "$(curl $CURLOPTS -X POST -d {\"clixon-example:input\":null} $proto://$addr/restconf/operations/clixon-example:empty)" 0 "HTTP/$HVER 415"

    new "restconf empty rpc, default media type should fail (JSON)"
    expectpart "$(curl $CURLOPTS -X POST -H "Accept: application/yang-data+json" -d {\"clixon-example:input\":null} $proto://$addr/restconf/operations/clixon-example:empty)" 0 "HTTP/$HVER 415"

    new "restconf empty rpc with extra args (should fail)"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d {\"clixon-example:input\":{\"extra\":null}} $proto://$addr/restconf/operations/clixon-example:empty)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"extra"},"error-severity":"error","error-message":"Unrecognized parameter: extra in rpc: empty"}}}'

    # Irritiating to get debugs on the terminal
    #new "restconf debug rpc"
    #expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d {\"clixon-lib:input\":{\"level\":0}} $proto://$addr/restconf/operations/clixon-lib:debug)" 0  "HTTP/$HVER 204"

    new "restconf get empty config + state json"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/data/clixon-example:state)" 0 "HTTP/$HVER 200" '{"clixon-example:state":{"op":\["41","42","43"\]}}'

    new "restconf get empty config + state json with wrong module name"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/data/badmodule:state)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"badmodule"},"error-severity":"error","error-message":"No such yang module prefix"}}}'

    #'HTTP/1.1 404 Not Found'
    #'{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"No such yang module: badmodule"}}}'

    new "restconf get empty config + state xml"
    ret=$(curl $CURLOPTS -H "Accept: application/yang-data+xml" -X GET $proto://$addr/restconf/data/clixon-example:state)
    expect='<state xmlns="urn:example:clixon"><op>41</op><op>42</op><op>43</op></state>'
    match=`echo $ret | grep --null -Eo "$expect"`
    if [ -z "$match" ]; then
        err "$expect" "$ret"
    fi

    new "restconf get data type json"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/data/clixon-example:state/op=42)" 0 '{"clixon-example:op":\["42"\]}'

    new "restconf get state operation"
    # Cant get shell macros to work, inline matching from lib.sh
    ret=$(curl $CURLOPTS -H "Accept: application/yang-data+xml" -X GET $proto://$addr/restconf/data/clixon-example:state/op=42)
    expect='<op xmlns="urn:example:clixon">42</op>'
    match=`echo $ret | grep --null -Eo "$expect"`
    if [ -z "$match" ]; then
        err "$expect" "$ret"
    fi

    new "restconf get state operation type json"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/data/clixon-example:state/op=42)" 0 '{"clixon-example:op":\["42"\]}'

    new "restconf get state operation type xml"
    # Cant get shell macros to work, inline matching from lib.sh
    ret=$(curl $CURLOPTS -H "Accept: application/yang-data+xml" -X GET $proto://$addr/restconf/data/clixon-example:state/op=42)
    expect='<op xmlns="urn:example:clixon">42</op>'
    match=`echo $ret | grep --null -Eo "$expect"`
    if [ -z "$match" ]; then
        err "$expect" "$ret"
    fi

    new "restconf GET datastore"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/data/clixon-example:state)" 0 "HTTP/$HVER 200" '{"clixon-example:state":{"op":\["41","42","43"\]}}'

    # Exact match
    new "restconf Add subtree eth/0/0 to datastore using POST"
    expectpart "$(curl $CURLOPTS -X POST -H "Accept: application/yang-data+json" -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interfaces":{"interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}}' $proto://$addr/restconf/data)" 0 "HTTP/$HVER 201" "Location: $proto://$addr/restconf/data/ietf-interfaces:interfaces"

# See test_json.sh
    new "restconf empty list"
    expectpart "$(curl $CURLOPTS -X POST -H "Accept: application/yang-data+json" -H "Content-Type: application/yang-data+json" -d '{"clixon-example:table":[]}' $proto://$addr/restconf/data)" 0 "HTTP/$HVER 201" "Location: $proto://$addr/restconf/data/clixon-example:table"

    new "restconf Re-add subtree eth/0/0 which should give error"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interfaces":{"interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}}' $proto://$addr/restconf/data)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-exists","error-severity":"error","error-message":"Data already exists; cannot create new resource"}}}'

    new "restconf Check interfaces eth/0/0 added"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/$HVER 200" '{"ietf-interfaces:interfaces":{"interface":\[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}\]}}'

    new "restconf delete interfaces"
    expectpart "$(curl $CURLOPTS -X DELETE $proto://$addr/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/$HVER 204"

    new "restconf Check empty config"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/data/clixon-example:state)" 0 "HTTP/$HVER 200" "$state"

    new "restconf Add interfaces subtree eth/0/0 using POST"
    expectpart "$(curl $CURLOPTS -X POST $proto://$addr/restconf/data/ietf-interfaces:interfaces -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}')" 0 "HTTP/$HVER 201"

    new "restconf Check eth/0/0 added config"
    expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $proto://$addr/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/$HVER 200" '{"ietf-interfaces:interfaces":{"interface":\[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}\]}}'

    new "restconf Check eth/0/0 GET augmented state level 1"
    expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $proto://$addr/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 "HTTP/$HVER 200" '{"ietf-interfaces:interface":\[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}\]}'

    new "restconf Check eth/0/0 GET augmented state level 2"
    expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $proto://$addr/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0/clixon-example:my-status)" 0 "HTTP/$HVER 200" '{"clixon-example:my-status":{"int":42,"str":"foo"}}' 

    new "restconf Check eth/0/0 added state"
    expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $proto://$addr/restconf/data/clixon-example:state)" 0 "HTTP/$HVER 200" '{"clixon-example:state":{"op":\["41","42","43"\]}}'

    new "restconf Re-post eth/0/0 which should generate error"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' $proto://$addr/restconf/data/ietf-interfaces:interfaces)" 0 '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-exists","error-severity":"error","error-message":"Data already exists; cannot create new resource"}}}'

    new "Add leaf description using POST"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:description":"The-first-interface"}' $proto://$addr/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 "HTTP/$HVER 201"

    new "Add nothing using POST (expect fail)"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $proto://$addr/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0  "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"The message-body of POST MUST contain exactly one instance of the expected data resource"}}}'

    new "restconf Check description added"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/$HVER 200" '{"ietf-interfaces:interfaces":{"interface":\[{"name":"eth/0/0","description":"The-first-interface","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}\]}}'

    new "restconf delete eth/0/0"
    expectpart "$(curl $CURLOPTS -X DELETE $proto://$addr/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 "HTTP/$HVER 204"

    new "Check deleted eth/0/0"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/data)" 0 "HTTP/$HVER 200" "$state"

    new "restconf Re-Delete eth/0/0 using none should generate error"
    expectpart "$(curl $CURLOPTS -X DELETE $proto://$addr/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 "HTTP/$HVER 409" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"data-missing","error-severity":"error","error-message":"Data does not exist; cannot delete resource"}}}'

    new "restconf Add subtree eth/0/0 using PUT"
    expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' $proto://$addr/restconf/data/ietf-interfaces:interfaces/interface=eth%2f0%2f0)" 0 "HTTP/$HVER 201"

    new "restconf get subtree"
    expectpart "$(curl $CURLOPTS -X GET $proto://$addr/restconf/data/ietf-interfaces:interfaces)" 0 "HTTP/$HVER 200" '{"ietf-interfaces:interfaces":{"interface":\[{"name":"eth/0/0","type":"clixon-example:eth","enabled":true,"oper-status":"up","clixon-example:my-status":{"int":42,"str":"foo"}}\]}}'

    new "restconf rpc using POST json"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"x":42}}' $proto://$addr/restconf/operations/clixon-example:example)" 0 "HTTP/$HVER 200" '{"clixon-example:output":{"x":"42","y":"42"}}'

    if ! $YANG_UNKNOWN_ANYDATA ; then
        new "restconf rpc using POST json wrong"
        expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-example:input":{"wrongelement":"ipv4"}}' $proto://$addr/restconf/operations/clixon-example:example)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"wrongelement"},"error-severity":"error","error-message":"Failed to find YANG spec of XML node: wrongelement with parent: example in namespace: urn:example:clixon"}}}'
    fi

    new "restconf rpc non-existing rpc without namespace"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{}' $proto://$addr/restconf/operations/kalle)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"missing-element","error-info":{"bad-element":"kalle"},"error-severity":"error","error-message":"RPC not defined"}}'

    new "restconf rpc non-existing rpc"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{}' $proto://$addr/restconf/operations/clixon-example:kalle)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"missing-element","error-info":{"bad-element":"kalle"},"error-severity":"error","error-message":"RPC not defined"}}'

    new "restconf rpc missing name"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{}' $proto://$addr/restconf/operations)" 0 "HTTP/$HVER 412" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"Operation name expected"}}}'

    new "restconf rpc missing input"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{}' $proto://$addr/restconf/operations/clixon-example:example)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"restconf RPC does not have input statement"}}}'

    new "restconf rpc using POST xml"
    ret=$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -H "Accept: application/yang-data+xml" -d '{"clixon-example:input":{"x":42}}' $proto://$addr/restconf/operations/clixon-example:example)
    expect='<output message-id="42" xmlns="urn:example:clixon"><x>42</x><y>42</y></output>'
    match=`echo $ret | grep --null -Eo "$expect"`
    if [ -z "$match" ]; then
        err "$expect" "$ret"
    fi

    new "restconf rpc using wrong prefix"
    expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"wrong:input":{"routing-instance-name":"ipv4"}}' $proto://$addr/restconf/operations/wrong:example)" 0 "HTTP/$HVER 412" '{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"operation-failed","error-severity":"error","error-message":"yang module not found"}}}'

    new "restconf local client rpc using POST xml"
    ret=$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -H "Accept: application/yang-data+xml" -d '{"clixon-example:input":{"x":"example"}}' $proto://$addr/restconf/operations/clixon-example:client-rpc)
    expect='<output xmlns="urn:example:clixon"><x>example</x></output>'
    match=`echo $ret | grep --null -Eo "$expect"`
    if [ -z "$match" ]; then
        err "$expect" "$ret"
    fi

    new "restconf Add subtree without key (expected error)"
    expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' $proto://$addr/restconf/data/ietf-interfaces:interfaces/interface)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"malformed key =interface, expected'

    new "restconf Add subtree with too many keys (expected error)"
    expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" -d '{"ietf-interfaces:interface":{"name":"eth/0/0","type":"clixon-example:eth","enabled":true}}' $proto://$addr/restconf/data/ietf-interfaces:interfaces/interface=a,b)" 0 "HTTP/$HVER 400" '{"ietf-restconf:errors":{"error":{"error-type":"rpc","error-tag":"malformed-message","error-severity":"error","error-message":"List key interface length mismatch"}}}'

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

protos=
# Go thru all combinations of IPv4/IPv6, http/https, local/backend config
if [ "${WITH_RESTCONF}" = "fcgi" ]; then
    protos="http"
elif ${HAVE_HTTP1}; then
    protos="http"    # No plain http for http/2 only
fi
if [ "${WITH_RESTCONF}" = "native" ]; then
    # https only relevant for internal (for fcgi: need nginx config)
    protos="$protos https"
fi
for proto in $protos; do
    addrs="127.0.0.1"
    if $IPv6 ; then
        addrs="$addrs \[::1\]"
    fi
    for addr in $addrs; do
        new "restconf test: proto:$proto addr:$addr HVER:$HVER"
        testrun $proto $addr
    done
done

# unset conditional parameters
unset HVER
unset RCPROTO

# Set by restconf_config
unset RESTCONFIG
unset RESTCONFIG1
unset ret

rm -rf $dir

new "endtest"
endtest
