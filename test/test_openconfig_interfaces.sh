#!/usr/bin/env bash
# Run a system around openconfig interface, ie: openconfig-if-ethernet
# Note first variant uses ietf-interfaces, maybe remove this?

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

# Generate autocli for these modules
AUTOCLI=$(autocli_config openconfig* kw-nokey false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>	
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  ${AUTOCLI}
</clixon-config>
EOF

# First using ietf-interfaces (not openconfig-interfaces)
# Example yang
cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:example";
  prefix ex;

  import ietf-interfaces { 
    prefix ietf-if; 
  }
  import openconfig-if-ethernet {
    prefix oc-eth;
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
fi

new "wait backend"
wait_backend

new "$clixon_cli -D $DBG -1f $cfg show version"
expectpart "$($clixon_cli -D $DBG -1f $cfg show version)" 0 "${CLIXON_VERSION}"

new "$clixon_netconf -qf $cfg"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><interfaces xmlns=\"http://openconfig.net/yang/interfaces\"><interface><name>e</name><config><name>e</name><type>ex:eth</type><loopback-mode>false</loopback-mode><enabled>true</enabled></config><hold-time><config><up>0</up><down>0</down></config></hold-time></interface></interfaces></data></rpc-reply>"

new "cli show configuration"
expectpart "$($clixon_cli -1 -f $cfg show conf xml)" 0 "^<interfaces xmlns=\"http://openconfig.net/yang/interfaces\">" --not-- "<oc-eth:ethernet xmlns:oc-eth=\"http://openconfig.net/yang/interfaces/ethernet\">"

# XXX THIS REQUIRES PREFIX FOR IETF-INTERFACES
#new "cli set interfaces interface <tab> complete: e"
#expectpart "$(echo "set interfaces interface 	" | $clixon_cli -f $cfg)" 0 "interface e"

# XXX See https://github.com/clicon/clixon/issues/218
#new "cli set interfaces interface e <tab> complete: not ethernet"
#expectpart "$(echo "set interfaces interface e 	" | $clixon_cli -f $cfg)" 0 config hold-time subinterfaces --not-- ethernet 

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


# Second using openconfig-interfaces instead
# Example yang
cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:example";
  prefix ex;

  import openconfig-vlan {
    prefix oc-vlan;
  }
  import openconfig-if-ethernet {
    prefix oc-eth;
  }
}
EOF

# Example system
cat <<EOF > $dir/startup_db
<config>
   <interfaces xmlns="http://openconfig.net/yang/interfaces">
      <interface>
         <name>eth1</name>
         <config>
            <name>eth1</name>
            <type>ianaift:ethernetCsmacd</type>
            <mtu>9206</mtu>
            <enabled>true</enabled>
            <oc-vlan:tpid xmlns:oc-vlan="http://openconfig.net/yang/vlan">oc-vlan-types:TPID_0X8100</oc-vlan:tpid>
         </config>
         <oc-eth:ethernet xmlns:oc-eth="http://openconfig.net/yang/interfaces/ethernet">
            <oc-eth:config>
               <oc-eth:mac-address>2c:53:4a:09:59:73</oc-eth:mac-address>
            </oc-eth:config>
         </oc-eth:ethernet>
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
fi

new "wait backend"
wait_backend

new "$clixon_cli -D $DBG -1f $cfg show version"
expectpart "$($clixon_cli -D $DBG -1f $cfg show version)" 0 "${CLIXON_VERSION}"

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
