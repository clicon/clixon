#!/usr/bin/env bash
# Clixon gRPC/gNMI test: start backend + clixon_grpc, run gNMI RPCs via grpcurl.
#
# Simple usecase: a YANG module with a single leaf, accessed via gNMI
# Capabilities, Get, and Set.
#
# Requires:
#   - clixon_grpc built with --enable-grpc
#   - grpcurl installed (https://github.com/fullstorydev/grpcurl)
#     installed from: https://github.com/fullstorydev/grpcurl/releases/tag/v1.9.3

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/example.yang
fyang2=$dir/example-aug.yang
fstate=$dir/state.xml

if [ "${enable_grpc}" != "yes" ]; then
    echo "...skipped: must run with --enable-grpc"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# Skip if clixon_grpc not installed
: ${clixon_grpc:=$(which clixon_grpc 2>/dev/null)}
if [ -z "$clixon_grpc" ]; then
    echo "...skipped: clixon_grpc not installed (use --enable-grpc)"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# Skip if grpcurl not installed
if ! which grpcurl > /dev/null 2>&1; then
    echo "...skipped: grpcurl not installed"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

# Proto files directory (set by config.sh after --enable-grpc, else default)
: ${GRPC_PROTO_DIR:=/usr/local/share/clixon/proto}

if [ ! -f "${GRPC_PROTO_DIR}/gnmi.proto" ]; then
    echo "...skipped: gNMI proto files not found in ${GRPC_PROTO_DIR}"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/backend.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# YANG module with a leaf, a container, and a list
cat <<EOF > $fyang
module example {
   namespace "urn:example:clixon";
   prefix ex;
   revision 2024-01-01 {
      description "Example module for gRPC test";
   }
   leaf val {
      type string;
      description "A simple test leaf";
   }
   leaf enabled {
      type boolean;
      description "A boolean leaf for typed-value tests";
   }
   leaf ratio {
      type decimal64 {
         fraction-digits 4;
      }
      description "A decimal64 leaf for typed-value tests";
   }
   container config {
      description "A simple container";
      leaf description {
         type string;
      }
   }
   list interface {
      key name;
      leaf name {
         type string;
      }
      leaf mtu {
         type uint32;
      }
   }
   leaf-list tags {
      type string;
      description "A leaf-list for leaf-list tests";
   }
   leaf uptime {
      config false;
      type uint32;
      description "A state-only (config false) leaf for DataType tests";
   }
}
EOF

# Second YANG module augmenting the interface list with an IP address leaf
# (different namespace — tests cross-namespace XPath path building)
cat <<EOF > $fyang2
module example-aug {
   namespace "urn:example:aug";
   prefix aug;
   import example {
      prefix ex;
   }
   revision 2024-01-01 {
      description "Augmentation module for gRPC test";
   }
   augment "/ex:interface" {
      leaf ip-address {
         type string;
         description "IP address (augmented leaf in different namespace)";
      }
   }
}
EOF

# grpcurl base command: plaintext, import proto + google well-known types
GRPCURL_OPTS="-plaintext -import-path ${GRPC_PROTO_DIR} -import-path /usr/include -proto gnmi.proto"

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend # to be sure
    sleep 1

    new "start backend -s init -f $cfg -- -sS $fstate"
    start_backend -s init -f $cfg -- -sS $fstate
fi

new "wait backend"
wait_backend

if [ $GR -ne 0 ]; then
    new "kill old grpc"
    stop_grpc_pre

    # Start gRPC daemon on GRPC_PORT
    new "start clixon_grpc"
    start_grpc -f $cfg -p ${GRPC_PORT}
fi

new "wait grpc"
wait_grpc

# -------------------------------------------------------------------
# Test 1: grpcurl list — discover available gRPC services
# -------------------------------------------------------------------
new "grpcurl list services"
expectpart "$(grpcurl $GRPCURL_OPTS list 2>&1)" \
    0 "gnmi.gNMI"

# -------------------------------------------------------------------
# Test 2: grpcurl list <service> — list methods of gNMI service
# -------------------------------------------------------------------
new "grpcurl list gnmi.gNMI methods"
expectpart "$(grpcurl $GRPCURL_OPTS list gnmi.gNMI 2>&1)" \
    0 "gnmi.gNMI.Capabilities" "gnmi.gNMI.Get" "gnmi.gNMI.Set" "gnmi.gNMI.Subscribe"

# -------------------------------------------------------------------
# Test 3: grpcurl describe — describe the gNMI service definition
# -------------------------------------------------------------------
new "grpcurl describe gnmi.gNMI"
expectpart "$(grpcurl $GRPCURL_OPTS describe gnmi.gNMI 2>&1)" \
    0 "gnmi.gNMI is a service" "Capabilities" "Get" "Set" "Subscribe"

# -------------------------------------------------------------------
# Test 4: gNMI Capabilities
# Expect JSON_IETF, JSON, and ASCII encodings advertised
# -------------------------------------------------------------------
new "gNMI Capabilities"
expectpart "$(grpcurl $GRPCURL_OPTS -d '{}' localhost:${GRPC_PORT} gnmi.gNMI/Capabilities 2>&1)" \
    0 "supportedModels" "example" "JSON_IETF" "JSON" "ASCII"

# -------------------------------------------------------------------
# Test 5: gNMI Get on empty datastore (leaf not yet set)
# Expect a successful response (empty notification list or empty val)
# -------------------------------------------------------------------
new "gNMI Get empty"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"val"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "notification"

# -------------------------------------------------------------------
# Test 6: gNMI Set a leaf value
# -------------------------------------------------------------------
new "gNMI Set val=hello"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"val"}]},"val":{"string_val":"hello"}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

# -------------------------------------------------------------------
# Test 7: gNMI Get the set value — expect "hello" back
# -------------------------------------------------------------------
new "gNMI Get val (expect hello)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"val"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "hello"

new "gNMI Get val with JSON_IETF encoding (expect jsonIetfVal key)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"val"}]}],"type":"ALL","encoding":"JSON_IETF"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "jsonIetfVal"

new "gNMI Get val with JSON encoding (expect jsonVal key)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"val"}]}],"type":"ALL","encoding":"JSON"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "jsonVal"

new "gNMI Get val with ASCII encoding (expect asciiVal with hello)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"val"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "asciiVal" "hello"

# -------------------------------------------------------------------
# Test 8: gNMI Set with replace — replace val with "world"
# -------------------------------------------------------------------
new "gNMI Set val=world (replace)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"replace":[{"path":{"elem":[{"name":"val"}]},"val":{"string_val":"world"}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get val (expect world after replace)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"val"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "world"

# -------------------------------------------------------------------
# Test 9: gNMI Set with delete — remove val
# -------------------------------------------------------------------
new "gNMI Set delete val"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"delete":[{"elem":[{"name":"val"}]}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get val (expect empty after delete)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"val"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "notification"

# -------------------------------------------------------------------
# Container tests
# -------------------------------------------------------------------

new "gNMI Set container leaf"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"config"},{"name":"description"}]},"val":{"string_val":"my-device"}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get container leaf (expect my-device)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"config"},{"name":"description"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "my-device"

# -------------------------------------------------------------------
# List tests
# -------------------------------------------------------------------

new "gNMI Set list entry eth0 mtu=1500"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"interface","key":{"name":"eth0"}},{"name":"mtu"}]},"val":{"uint_val":1500}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get list entry eth0 mtu (expect 1500)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"interface","key":{"name":"eth0"}},{"name":"mtu"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "1500"

new "gNMI Set list entry eth1 mtu=9000"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"interface","key":{"name":"eth1"}},{"name":"mtu"}]},"val":{"uint_val":9000}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get all interfaces (expect eth0 and eth1)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"interface"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "eth0" "eth1"

new "gNMI Set delete list entry eth0"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"delete":[{"elem":[{"name":"interface","key":{"name":"eth0"}}]}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get all interfaces (expect only eth1 after delete)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"interface"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "eth1" --not-- "eth0"

# -------------------------------------------------------------------
# Leaf-list tests: populate via NETCONF, then read back via gNMI
# -------------------------------------------------------------------

new "NETCONF: set leaf-list tags [alpha, beta, gamma]"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><tags xmlns=\"urn:example:clixon\">alpha</tags><tags xmlns=\"urn:example:clixon\">beta</tags><tags xmlns=\"urn:example:clixon\">gamma</tags></config></edit-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "NETCONF: commit leaf-list tags"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "gNMI Get leaf-list (expect alpha, beta, gamma)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"tags"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "alpha" "beta" "gamma"

# -------------------------------------------------------------------
# Augmented namespace tests
# a different namespace from the interface list ("urn:example:clixon").
# This exercises cross-namespace XPath path building in gnmi_get.
# -------------------------------------------------------------------

new "gNMI Set augmented leaf (cross-namespace path, module-qualified)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"interface","key":{"name":"eth1"}},{"name":"example-aug:ip-address"}]},"val":{"string_val":"192.0.2.1"}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get augmented leaf (expect 192.0.2.1)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"interface","key":{"name":"eth1"}},{"name":"example-aug:ip-address"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "192.0.2.1"

new "gNMI Set augmented leaf (unqualified fallback, no module prefix)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"interface","key":{"name":"eth1"}},{"name":"ip-address"}]},"val":{"string_val":"192.0.2.2"}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get augmented leaf via unqualified path (expect 192.0.2.2)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"interface","key":{"name":"eth1"}},{"name":"ip-address"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "192.0.2.2"

# -------------------------------------------------------------------
# Typed-value tests: exercise all supported gNMI TypedValue encodings
# -------------------------------------------------------------------

new "gNMI Set boolean leaf via bool_val (true)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"enabled"}]},"val":{"bool_val":true}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get boolean leaf (expect true)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"enabled"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "true"

new "gNMI Set boolean leaf via bool_val (false)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"enabled"}]},"val":{"bool_val":false}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get boolean leaf (expect false)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"enabled"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "false"

new "gNMI Set decimal64 leaf via uint_val (3)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"ratio"}]},"val":{"uint_val":"3"}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get decimal64 leaf (expect 3)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"ratio"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "3"

new "gNMI Set decimal64 leaf via double_val (2.5)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"ratio"}]},"val":{"double_val":2.5}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get decimal64 leaf (expect 2.5)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"ratio"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "2.5"

new "gNMI Set string leaf via ascii_val"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"val"}]},"val":{"ascii_val":"ascii-test"}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get string leaf set via ascii_val (expect ascii-test)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[{"name":"val"}]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "ascii-test"

# -------------------------------------------------------------------
# Error handling tests
# -------------------------------------------------------------------
new "gNMI Set invalid YANG path — expect FailedPrecondition"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"nonexistent"}]},"val":{"string_val":"x"}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    73 "FailedPrecondition"

# -------------------------------------------------------------------
# DataType (type) filter tests: ALL / CONFIG / STATE
# -------------------------------------------------------------------

# Write state data file — uptime is config false (state only)
cat <<EOF > $fstate
<uptime xmlns="urn:example:clixon">99</uptime>
EOF

# Set a config leaf so we have something config-only too
new "gNMI Set val=config-leaf for DataType tests"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"val"}]},"val":{"string_val":"config-leaf"}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "response"

new "gNMI Get type=ALL (expect both config and state)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[]}],"type":"ALL","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "config-leaf" "99"

new "gNMI Get type=CONFIG (expect config leaf, not state)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[]}],"type":"CONFIG","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "config-leaf" --not-- "99"

new "gNMI Get type=STATE (expect state leaf, not config)"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"path":[{"elem":[]}],"type":"STATE","encoding":"ASCII"}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Get 2>&1)" \
    0 "99" --not-- "config-leaf"

# -------------------------------------------------------------------
# Subscribe ONCE tests
# -------------------------------------------------------------------
new "gNMI Set val=subscribe-test for Subscribe tests"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"update":[{"path":{"elem":[{"name":"val"}]},"val":{"asciiVal":"subscribe-test"}}]}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Set 2>&1)" \
    0 "UPDATE"

new "gNMI Subscribe ONCE — expect update with path and sync_response"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"subscribe":{"mode":"ONCE","subscription":[{"path":{"elem":[{"name":"val"}]}}]}}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Subscribe 2>&1)" \
    0 "update" "syncResponse"

new "gNMI Subscribe ONCE — val path: expect subscribe-test value in asciiVal"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"subscribe":{"mode":"ONCE","encoding":"ASCII","subscription":[{"path":{"elem":[{"name":"val"}]}}]}}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Subscribe 2>&1)" \
    0 "subscribe-test" "syncResponse"

new "gNMI Subscribe ONCE — root path: expect multiple fields"
expectpart "$(grpcurl $GRPCURL_OPTS \
    -d '{"subscribe":{"mode":"ONCE","encoding":"ASCII","subscription":[{"path":{"elem":[]}}]}}' \
    localhost:${GRPC_PORT} gnmi.gNMI/Subscribe 2>&1)" \
    0 "syncResponse"

if [ $GR -ne 0 ]; then
    new "stop grpc"
    stop_grpc
fi

if [ $BE -ne 0 ]; then
    new "kill backend"
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
