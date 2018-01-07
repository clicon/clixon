#!/bin/bash
# Advanced union types and generated code
# and enum w values

# include err() and new() functions and creates $dir
. ./lib.sh
fyang=$dir/type.yang
cfg=$dir/conf_yang.xml

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
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


# For memcheck
#clixon_cli="valgrind --leak-check=full --show-leak-kinds=all clixon_cli"
clixon_cli=clixon_cli
clixon_netconf=clixon_netconf

cat <<EOF > $fyang
module example{
  typedef ab {
       type string {
         pattern
           '(([a-b])\.){3}[a-b]';
       }
   }
  typedef cd {
       type string {
         pattern
           '(([c-d])\.){3}[c-d]';
       }
   }
  typedef ef {
       type string {
         pattern
           '(([e-f])\.){3}[e-f]';
         length "1..253";
       }
   }
  typedef ad {
       type union {
         type ab;
         type cd;
       }
   }
   typedef af {
       type union {
         type ad;
         type ef;
       }
   }
   list list {
     key ip;
     leaf ip {
         type af; 
     }
   }
   leaf status {
      type enumeration {
         enum up {
            value 1;
         }
         enum down;
      }
   }
}
EOF


# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err
fi
new "start backend -s init -f $cfg -y $fyang"
sudo clixon_backend -s init -f $cfg -y $fyang
if [ $? -ne 0 ]; then
    err
fi

new "cli set ab"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set list a.b.a.b" "^$"

new "cli set cd"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set list c.d.c.d" "^$"

new "cli set ef"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set list e.f.e.f" "^$"

new "cli set ab fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set list a&b&a&b" "^CLI syntax error"

new "cli set ad fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set list a.b.c.d" "^CLI syntax error"

new "cli validate"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang -l o validate" "^$"

new "cli commit"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang -l o commit" "^$"

new "netconf validate ok"
expecteof "$clixon_netconf -qf $cfg -y $fyang" "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf set ab wrong"
expecteof "$clixon_netconf -qf $cfg -y $fyang" "<rpc><edit-config><target><candidate/></target><config><list><ip>a.b&c.d</ip></list></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error>"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg -y $fyang" "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "cli enum value"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set status down" "^$"

new "Kill backend"
# Check if still alive
pid=`pgrep clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
