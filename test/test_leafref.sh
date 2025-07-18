#!/usr/bin/env bash
# Yang leafref test

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/leafref.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example{
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    import ietf-interfaces {
        prefix if;
    }
    import ietf-ip {
      prefix ip;
    }
    identity eth {
        base if:interface-type;
    }
    identity lo {
        base if:interface-type;
    }
    container default-address {
         leaf absname {
             description "Absolute references existing interfaces in if module";
             type leafref {
                 path "/if:interfaces/if:interface/if:name";
                 require-instance true;
             }
         }
         leaf relname {
             type leafref {
                 path "../../if:interfaces/if:interface/if:name";
                 require-instance true;                          
             }
         }
         leaf address {
             description "From RFC7950 9.9.6";
             type leafref {
                 path "../../if:interfaces/if:interface[if:name = current()/../relname]"
                    + "/ip:ipv4/ip:address/ip:ip";
                 require-instance true;
            }
         }
         leaf anyaddr {
             description "see https://github.com/clicon/clixon/issues/613";
             type leafref {
                 path "../../if:interfaces/if:interface"
                    + "/ip:ipv4/ip:address/ip:ip";
                 require-instance true;
            }
         }
         leaf wrong {
             description "References leading nowhere in yang";
             type leafref {
                 path "/ip:interfaces/ip:interface/ip:name";
                 require-instance true;
             }
         }
    }
    list sender{
        key name;
        leaf name{
            type string;
        }
        leaf template{
            type leafref{
                path "/sender/name";
                require-instance true;  
            }
        }
    }
}
EOF

BASEXML=$(cat <<EOF
<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces" xmlns:ex="urn:example:clixon">
   <interface xmlns:ip="urn:ietf:params:xml:ns:yang:ietf-ip">
      <name>eth0</name>
      <type>ex:eth</type>
      <ip:ipv4>
         <ip:address>
            <ip:ip>192.0.2.1</ip:ip>
            <ip:prefix-length>24</ip:prefix-length>
         </ip:address>
         <ip:address>
            <ip:ip>192.0.2.2</ip:ip>
            <ip:prefix-length>24</ip:prefix-length>
         </ip:address>
      </ip:ipv4>
   </interface>
   <interface xmlns:ip="urn:ietf:params:xml:ns:yang:ietf-ip">
      <name>lo</name>
      <type>ex:lo</type>
      <ip:ipv4>
         <ip:address>
            <ip:ip>127.0.0.1</ip:ip>
            <ip:prefix-length>32</ip:prefix-length>
         </ip:address>
      </ip:ipv4>
   </interface>
</interfaces>
EOF
)

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend  -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "leafref base config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$BASEXML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref get config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data>$BASEXML</data></rpc-reply>" ""

new "leafref base commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref add non-existing ref"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><default-address xmlns=\"urn:example:clixon\"><absname>eth3</absname><address>10.0.4.6</address></default-address></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref validate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>instance-required</error-app-tag><error-path>/if:interfaces/if:interface/if:name</error-path><error-info><absname>eth3</absname></error-info><error-severity>error</error-severity></rpc-error></rpc-reply>" ""

#new "leafref wrong ref"
#expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><default-address xmlns=\"urn:example:clixon\"><wrong>eth3</wrong><address>10.0.4.6</address></default-address></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref add correct absref"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><default-address xmlns=\"urn:example:clixon\"><absname>eth0</absname></default-address></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref validate ok 1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref add correct relref"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><default-address xmlns=\"urn:example:clixon\"><relname>eth0</relname></default-address></config></edit-config></rpc>]]>]]>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref validate ok 2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref add correct address"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><default-address xmlns=\"urn:example:clixon\"><address>192.0.2.1</address></default-address></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref validate ok 3"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref add second any address"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><default-address xmlns=\"urn:example:clixon\"><anyaddr>127.0.0.1</anyaddr></default-address></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref validate ok 4"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref delete leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\" xmlns:nc=\"${BASENS}\"><interface nc:operation=\"delete\"><name>eth0</name></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref validate (should fail)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>instance-required</error-app-tag><error-path>/if:interfaces/if:interface/if:name</error-path><error-info><absname>eth0</absname></error-info><error-severity>error</error-severity></rpc-error></rpc-reply>" ""

new "leafref discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "cli leafref lo"
expectpart "$($clixon_cli -1f $cfg -l o set default-address absname lo)" 0 "^$"

new "cli leafref validate"
expectpart "$($clixon_cli -1f $cfg -l o validate)" 0 "^$"

new "cli sender"
expectpart "$($clixon_cli -1f $cfg -l o set sender a)" 0 "^$"

new "cli sender template"
expectpart "$($clixon_cli -1f $cfg -l o set sender b template a)" 0 "^$"

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
