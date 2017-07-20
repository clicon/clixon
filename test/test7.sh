#!/bin/bash
# Test7: Yang specifics: leafref

# include err() and new() functions
. ./lib.sh

# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
clixon_netconf=clixon_netconf
clixon_cli=clixon_cli

cat <<EOF > /tmp/leafref.yang
module example{
     typedef admin-status{
        type string;
     }
     list interface {
         key "name";
         leaf name {
             type string;
         }
         leaf admin-status {
             type admin-status;
         }
         list address {
             key "ip";
             leaf ip {
                 type string;
             }
         }
     }
     container default-address {
         leaf ifname {
             type leafref {
                 path "../../interface/name";
             }
         }
         leaf address {
             type leafref {
                 path "../../interface[name=eth0]"
                    + "/address/ip";
             }
         }
    }
}
EOF
#                 path "../../interface[name = current()/../ifname]"

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $clixon_cf -y /tmp/leafref
if [ $? -ne 0 ]; then
    err
fi

new "start backend"
# start new backend
sudo clixon_backend -If $clixon_cf -y /tmp/leafref
if [ $? -ne 0 ]; then
    err
fi

new "leafref base config"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/leafref" "<rpc><edit-config><target><candidate/></target><config><interface><name>eth0</name><admin-status>up</admin-status><address><ip>192.0.2.1</ip></address><address><ip>192.0.2.2</ip></address></interface><interface><name>lo</name><admin-status>up</admin-status><address><ip>127.0.0.1</ip></address></interface></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "leafref get config"
expecteof "$clixon_netconf -qf $clixon_cf" '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<rpc-reply><data><config><interface><name>eth0</name>'

new "leafref base commit"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/leafref" "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "leafref add wrong ref"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/leafref" "<rpc><edit-config><target><candidate/></target><config><default-address><ifname>eth3</ifname><address>10.0.4.6</address></default-address></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "leafref validate"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/leafref" "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-tag>missing-attribute</error-tag>"

new "leafref discard-changes"
expecteof "$clixon_netconf -qf $clixon_cf" "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "leafref add correct ref"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/leafref" "<rpc><edit-config><target><candidate/></target><config><default-address><ifname>eth0</ifname><address>192.0.2.2</address></default-address></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "leafref validate (ok)"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/leafref" "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>"

new "leafref delete leaf"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/leafref" "<rpc><edit-config><target><candidate/></target><config><interface operation=\"delete\"><name>eth0</name></interface></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>"

new "leafref validate (should fail)"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/leafref" "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>"  "^<rpc-reply><rpc-error><error-tag>missing-attribute</error-tag>"


new "Kill backend"
# Check if still alive
pid=`pgrep clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -zf $clixon_cf
if [ $? -ne 0 ]; then
    err "kill backend"
fi
