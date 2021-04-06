#!/usr/bin/env bash
# Parse "all" openconfig yangs from https://github.com/openconfig/public
# Notes:
# Notes:
# - A simple smoketest (CLI check) is made, essentially YANG parsing. 
#    - A full system is worked on
# - Env-var OPENCONFIG should point to checkout place. (define it in site.sh for example)
# - Env variable YANGMODELS should point to checkout place. (define it in site.sh for example)
# - Some DIFFs are necessary in yangmodels
#         release/models/wifi/openconfig-ap-interfaces.yang

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang

new "openconfig"
if [ ! -d "$OPENCONFIG" ]; then
#    err "Hmm Openconfig dir does not seem to exist, try git clone https://github.com/openconfig/public?"
    echo "...skipped: OPENCONFIG not set"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

OCDIR=$OPENCONFIG/release/models

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>$OPENCONFIG/third_party/ietf/</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/acl</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/aft</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/bfd</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/bgp</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/catalog</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/interfaces</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/isis</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/lacp</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/lldp</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/local-routing</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/macsec</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/mpls</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/multicast</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/network-instance</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/openflow</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/optical-transport</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/ospf</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/platform</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/policy</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/policy-forwarding</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/probes</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/qos</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/relay-agent</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/rib</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/segment-routing</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/stp</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/system</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/telemetry</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/types</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/vlan</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi/access-points</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi/ap-manager</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi/mac</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi/phy</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR/wifi/types</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>	
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_AUTOCLI_EXCLUDE>clixon-restconf ietf-interfaces</CLICON_CLI_AUTOCLI_EXCLUDE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

# Example yang
cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:example";
  prefix ex;

  import ietf-interfaces { 
    prefix ietf-if; 
  }
  import openconfig-interfaces {
    prefix oc-if;
  }
  identity eth { /* Need to create an interface-type identity for leafrefs */
    base ietf-if:interface-type;
  }
}
EOF

# Example system
cat <<EOF > $dir/startup_db
<config>
  <interfaces xmlns="http://openconfig.net/yang/interfaces">
    <interface>
      <name>e</name>
      <config>
         <name>e</name>
         <type>ex:eth</type>
         <loopback-mode>false</loopback-mode>
         <enabled>true</enabled>
      </config>
      <hold-time>
         <config>
            <up>0</up>
            <down>0</down>
         </config>
      </hold-time>
    </interface>
  </interfaces>
</config>
EOF

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure
    
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg

    new "wait backend"
    wait_backend
fi

new "$clixon_cli -D $DBG -1f $cfg -y $f show version"
expectpart "$($clixon_cli -D $DBG -1f $cfg show version)" 0 "${CLIXON_VERSION}"

new "$clixon_netconf -qf $cfg"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"http://openconfig.net/yang/interfaces\"><interface><name>e</name><config><name>e</name><type>ex:eth</type><loopback-mode>false</loopback-mode><enabled>true</enabled></config><hold-time><config><up>0</up><down>0</down></config></hold-time></interface></interfaces></data></rpc-reply>]]>]]>"

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
