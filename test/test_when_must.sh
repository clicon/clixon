#!/usr/bin/env bash
# Yang  when and must conditional xpath specification
# Testing of validation phase.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module $APPNAME{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  identity routing-protocol {
     description
        "Base identity from which routing protocol identities are
         derived.";
  }
  identity direct {
       base routing-protocol;
       description
         "Routing pseudo-protocol which provides routes to directly
          connected networks.";
  }
  identity static {
       base routing-protocol;
       description
         "Static routing pseudo-protocol.";
  }
  list whenex {
     key "type name";
     leaf type {
        type identityref {
           base routing-protocol;
        }
     }
     leaf name {
        type string;
     }
     leaf route-preference {
        type uint32;
     }
     container static-routes {
         when "../type='static'" {
            description
               "This container is only valid for the 'static'
                routing protocol.";
         }
         presence true;
     }
  }
  container interface {
     leaf ifType {
        type enumeration {
           enum ethernet;
           enum atm;
        }
     }
     leaf ifMTU {
        type uint32;
     }
     must 'ifType != "ethernet" or ifMTU = 1500' {
        error-message "An Ethernet MTU must be 1500";
     }
     must 'ifType != "atm" or'
          + ' (ifMTU <= 17966 and ifMTU >= 64)' {
        error-message "An ATM MTU must be 64 .. 17966";
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
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg

    new "waiting"
    wait_backend
fi

new "when: add static route"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><whenex xmlns="urn:example:clixon"><type>static</type><name>r1</name><static-routes/></whenex></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "when: validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "when: add direct route"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><whenex xmlns="urn:example:clixon"><type>direct</type><name>r2</name><static-routes/></whenex></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "when get config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><whenex xmlns="urn:example:clixon"><type>direct</type><name>r2</name><static-routes/></whenex><whenex xmlns="urn:example:clixon"><type>static</type><name>r1</name><static-routes/></whenex></data></rpc-reply>]]>]]>$'

new "when: validate fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>when xpath validation failed</error-message></rpc-error></rpc-reply>]]>]]>$"

new "when: discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "must: add interface"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interface xmlns="urn:example:clixon"><ifType>ethernet</ifType><ifMTU>1500</ifMTU></interface></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "must: validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "must: add atm interface"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interface xmlns="urn:example:clixon"><ifType>atm</ifType><ifMTU>32</ifMTU></interface></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "must: atm validate fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>An ATM MTU must be 64 .. 17966</error-message></rpc-error></rpc-reply>]]>]]>$"

new "must: add eth interface"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><interface xmlns="urn:example:clixon"><ifType>ethernet</ifType><ifMTU>989</ifMTU></interface></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "must: eth validate fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>An Ethernet MTU must be 1500</error-message></rpc-error></rpc-reply>]]>]]>"

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
