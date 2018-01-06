#!/bin/bash
# Advanced union types and generated code
# and enum w values

# include err() and new() functions
. ./lib.sh
cfg=/usr/local/etc/routing.xml
fyang=/tmp/type.yang

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

