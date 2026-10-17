#!/usr/bin/env bash
# Yang leafref with empty value
# An empty value must refer to an existing instance with empty value, as any other value
# See https://github.com/clicon/clixon/issues/647

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
module leafref{
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    container groups {
        leaf-list name {
            type string;
        }
    }
    list zone {
        key name;
        leaf name {
            type string;
        }
        leaf label {
            type string;
        }
    }
    container test {
        list object {
            key id;
            leaf id {
                type string;
            }
            leaf group {
                description "leafref to leaf-list";
                type leafref {
                    path "/ex:groups/ex:name";
                }
            }
            leaf zone {
                description "leafref to list key";
                type leafref {
                    path "/ex:zone/ex:name";
                }
            }
            leaf label {
                description "leafref to non-key list leaf";
                type leafref {
                    path "/ex:zone/ex:label";
                }
            }
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
    new "start backend  -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "netconf set groups and zones"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><groups xmlns=\"urn:example:clixon\"><name>g1</name><name>g2</name></groups><zone xmlns=\"urn:example:clixon\"><name>z1</name><label>a</label></zone><zone xmlns=\"urn:example:clixon\"><name>z2</name><label>b</label></zone><zone xmlns=\"urn:example:clixon\"><name>z3</name><label>c</label></zone></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit groups and zones"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set non-empty refs"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><test xmlns=\"urn:example:clixon\"><object><id>o1</id><group>g2</group><zone>z2</zone><label>c</label></object></test></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate non-empty refs ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set empty leafref to leaf-list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><test xmlns=\"urn:example:clixon\"><object><id>o1</id><group/></object></test></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate empty leafref to leaf-list not ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>instance-required</error-app-tag><error-path>/ex:groups/ex:name</error-path><error-info><group/></error-info>" ""

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set empty leafref to list key"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><test xmlns=\"urn:example:clixon\"><object><id>o1</id><zone></zone></object></test></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate empty leafref to list key not ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>instance-required</error-app-tag><error-path>/ex:zone/ex:name</error-path><error-info><zone/></error-info>" ""

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set empty leafref to non-key leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><test xmlns=\"urn:example:clixon\"><object><id>o1</id><label/></object></test></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate empty leafref to non-key leaf not ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>instance-required</error-app-tag><error-path>/ex:zone/ex:label</error-path><error-info><label/></error-info>" ""

new "netconf set referred non-key leaf to empty value"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><zone xmlns=\"urn:example:clixon\"><name>z3</name><label/></zone></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate empty leafref to existing empty value ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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
