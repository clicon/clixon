#!/usr/bin/env bash
# Netconf framing functionality
# See RFC6242 and RFC 4742
# See test_netconf_hello.sh for hello protocol negotiation only

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang
tmp=$dir/tmp.x

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE> 
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_NETCONF_BASE_CAPABILITY>1</CLICON_NETCONF_BASE_CAPABILITY>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
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
       }
  }
}
EOF

new "test params: -f $cfg -- -s"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend  -s init -f $cfg -- -s"
    start_backend -s init -f $cfg -- -s
fi

new "wait backend"
wait_backend

# Hello
new "Netconf 1.0 eom framing, edit-config"
expecteof "$clixon_netconf -qef $cfg -o CLICON_NETCONF_BASE_CAPABILITY=0" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability></capabilities></hello>]]>]]><rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config><table xmlns=\"urn:example:clixon\"><parameter><name>a</name></parameter></table></config></edit-config></rpc>]]>]]>$" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Netconf 1.0 eom framing get-config"
expecteof "$clixon_netconf -qef $cfg -o CLICON_NETCONF_BASE_CAPABILITY=0" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability></capabilities></hello>]]>]]><rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>$" "^<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><parameter><name>a</name></parameter></table></data></rpc-reply>]]>]]>$"

new "Netconf 1.1 eom framing, expect error"
expecteof "$clixon_netconf -qef $cfg -o CLICON_NETCONF_BASE_CAPABILITY=1" 255 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]><rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>$" ""

new "Netconf 1.1 chunked framing"
expecteof_netconf "$clixon_netconf -qef $cfg -o CLICON_NETCONF_BASE_CAPABILITY=1" 0 "<?xml version=\"1.0\" encoding=\"UTF-8\"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><parameter><name>a</name></parameter></table></data></rpc-reply>"

# cant use expecteof_netconf since it relies on a whole frame, here we split into multiple
rpc=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?><hello $DEFAULTNS><capabilities><capability>urn:ietf:params:netconf:base:1.1</capability></capabilities></hello>]]>]]>
#85
<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="42"><get-config><sou
#44
rce><candidate/></source></get-config></rpc>
##
EOF
   )

new "Netconf 1.1 multi-chunked framing"
expecteof_netconf "$clixon_netconf -qef $cfg -o CLICON_NETCONF_BASE_CAPABILITY=1" 0 "$rpc" "" "" "<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><parameter><name>a</name></parameter></table></data></rpc-reply>"

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
