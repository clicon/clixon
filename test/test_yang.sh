#!/bin/bash
# Test4: Yang specifics: multi-keys and empty type

# include err() and new() functions
. ./lib.sh
clixon_cf=/tmp/conf_yang.xml

# For memcheck
# clixon_netconf="valgrind --leak-check=full --show-leak-kinds=all clixon_netconf"
clixon_netconf=clixon_netconf
clixon_cli=clixon_cli

cat <<EOF > /tmp/conf_yang.xml
<config>
  <CLICON_CONFIGFILE>/tmp/test_yang.xml</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/routing/yang</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/routing/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/routing/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>routing</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/routing/routing.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/routing/routing.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/routing</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

cat <<EOF > /tmp/test.yang
module example{
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
    container nopresence {
      description "No presence should be removed if no children";
      leaf j {
        type string;
      }
    }
    container presence {
      description "Presence should not be removed even if no children";
      presence "even if empty should remain";
      leaf j {
        type string;
      }
    }
    anyxml any{
      description "testing of anyxml";
    }
  }
  container state {
    config false;
    leaf-list op {
      type string;
    }
  }
}
EOF

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $clixon_cf -y /tmp/test.yang
if [ $? -ne 0 ]; then
    err
fi

new "start backend"
# start new backend
sudo clixon_backend -s init -f $clixon_cf -y /tmp/test.yang
if [ $? -ne 0 ]; then
    err
fi

new "netconf edit config"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><edit-config><target><candidate/></target><config><x><y><a>1</a><b>2</b><c>5</c></y><d/></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# text empty type in running
new "netconf commit 2nd"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get config xpath"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/y[a=1][b=2]\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><x><y><a>1</a><b>2</b><c>5</c></y></x></data></rpc-reply>]]>]]>$"

new "netconf edit leaf-list"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><edit-config><target><candidate/></target><config><x><f><e>hej</e><e>hopp</e></f></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get leaf-list"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/f/e\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><x><f><e>hej</e><e>hopp</e></f></x></data></rpc-reply>]]>]]>$"

new "netconf get leaf-list path"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/f[e=hej]\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><x><f><e>hej</e><e>hopp</e></f></x></data></rpc-reply>]]>]]>$"

new "netconf get (should be some)"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><get><filter type=\"xpath\" select=\"/\"/></get></rpc>]]>]]>" "^<rpc-reply><data><x><y><a>1</a><b>2</b><c>5</c></y><d/></x></data></rpc-reply>]]>]]>$"

new "cli set leaf-list"
expectfn "$clixon_cli -1f $clixon_cf -y /tmp/test.yang set x f e foo" ""

new "cli show leaf-list"
expectfn "$clixon_cli -1f $clixon_cf -y /tmp/test.yang show xpath /x/f/e" "<e>foo</e>"
new "netconf set state data (not allowed)"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><edit-config><target><candidate/></target><config><state><op>42</op></state></config></edit-config></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-tag>invalid-value"

new "netconf set presence and not present"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><edit-config><target><candidate/></target><config><x><nopresence/><presence/></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get presence only"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/x/*presence"/></get-config></rpc>]]>]]>' "^<rpc-reply><data><x><presence/></x></data></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $clixon_cf" "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf anyxml"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><edit-config><target><candidate/></target><config><x><any><foo><bar a=\"nisse\"/></foo></any></x></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate anyxml"
expecteof "$clixon_netconf -qf $clixon_cf -y /tmp/test.yang" "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

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
