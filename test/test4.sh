#!/bin/bash
# Test4: Yang specifics: multi-keys and empty type

# include err() and new() functions
. ./lib.sh

# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
clixon_netconf=clixon_netconf

cat <<EOF > /tmp/test.yang
module ietf-ip{
   container x {
    list y {
      key "a b";
      leaf a {
        type string;
      }
      leaf b {
        type string;
      }
      leaf c {
        type string;
      }   
    }
    leaf d {
        type empty;
    }
    container f {
      leaf-list e {
        type string;
      }
    }
    leaf g {
      type string;  
    }
    container h {
      leaf j {
        type string;
      }
    }
  }
}
EOF

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $clixon_cf -y /tmp/test
if [ $? -ne 0 ]; then
    err
fi

new "start backend"
# start new backend
sudo clixon_backend -If $clixon_cf -y /tmp/test
if [ $? -ne 0 ]; then
    err
fi
new "netconf edit config"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test" "<rpc><edit-config><target><candidate/></target><config><x><y><a>1</a><b>2</b><c>5</c></y><d/></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test" "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get config xpath"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test" "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/y[a=1][b=2]\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><config><x><y><a>1</a><b>2</b><c>5</c></y></x></config></data></rpc-reply>]]>]]>$"

new "netconf edit leaf-list"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test" "<rpc><edit-config><target><candidate/></target><config><x><f><e>hej</e><e>hopp</e></f></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get leaf-list"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test" "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/f/e\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><config><x><f><e>hej</e><e>hopp</e></f></x></config></data></rpc-reply>]]>]]>$"

new "netconf get leaf-list path"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test" "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/f[e=hej]\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><config><x><f><e>hej</e><e>hopp</e></f></x></config></data></rpc-reply>]]>]]>$"

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
