#!/bin/bash
# Advanced union types and generated code
# and enum w values
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyang=$dir/type.yang
fyang2=$dir/example2.yang
fyang3=$dir/example3.yang

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/$APPNAME/yang</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_XMLDB_CACHE>false</CLICON_XMLDB_CACHE>
</config>
EOF

# transitive type, exists in fyang3, referenced from fyang2, but not declared in fyang
cat <<EOF > $fyang3
module example3{
  prefix ex3;
  namespace "urn:example:example3";
  typedef w{
    type union{
       type int32{
          range "4..44";
       }
    }
  }
  typedef u{
     type union {
       type w;
       type enumeration {
         enum "bounded";
         enum "unbounded";
       }
     }
  }
  typedef t{
    type string{
      pattern '[a-z][0-9]*';
    }
  }
}
EOF
cat <<EOF > $fyang2
module example2{
  import example3 { prefix ex3; }
  namespace "urn:example:example2";
  prefix ex2;
  grouping gr2 {
    leaf talle{
      type ex3:t;
    }
    leaf ulle{
      type ex3:u;
    }
  }
}
EOF
cat <<EOF > $fyang
module example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import example2 { prefix ex2; }
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
   leaf length1 {
       type string {
       length "1";
      }
   }
/*   leaf length2 {
       type string {
         length "max";
      }
   }
   leaf length3 {
       type string {
         length "min";
      }
   }*/
   leaf length4 {
       type string {
         length "4..4000";
      }
   }
/*   leaf length5 {
       type string {
         length "min..max";
      }
   }*/
   leaf num1 {
       type int32 {
       range "1";
      }
   }
/*   leaf num2 {
       type int32 {
         range "min";
      }
   }
   leaf num3 {
       type int32 {
         range "max";
      }
   }
*/
   leaf num4 {
       type int32 {
         range "4..4000";
      }
   }
/*   leaf num5 {
       type int32 {
         range "min..max";
      }
   }*/
   typedef mybits {
        description "Test adding several bits";
	type bits {
	    bit create;
	    bit read;
	    bit write;
        }
   }
   leaf mbits{
      type mybits;
   }
  container c{
    description "transitive type- exists in ex3";
    uses ex2:gr2;
  }
}
EOF

new "test params: -f $cfg -y $fyang"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg -y $fyang"
    sudo $clixon_backend -s init -f $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "cli set transitive string"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c talle x99" 0 "^$"

new "cli set transitive string error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c talle 9xx" 255 "^$"

new "netconf set transitive string error"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><c><talle>9xx</talle></c></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>"

new "netconf validate should fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>talle</bad-element></error-info><error-severity>error</error-severity><error-message>regexp match fail: "9xx" does not match \[a-z\]\[0-9\]\*</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "cli set transitive union int"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c ulle 33" 0 "^$"

new "cli validate"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang -l o validate" 0 "^$"

new "cli set transitive union string"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c ulle unbounded" 0 "^$"

new "cli validate"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang -l o validate" 0 "^$"

new "cli set transitive union error. should fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c ulle kalle" 255 ""

new "cli set transitive union error int"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c ulle 55" 255 ""

new "netconf set transitive union error int"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><c><ulle>55</ulle></c></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>"

new "netconf validate should fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>ulle</bad-element></error-info><error-severity>error</error-severity><error-message>'55' does not match enumeration</error-message></rpc-error></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#-----------

new "cli set ab"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set list a.b.a.b" 0 "^$"

new "cli set cd"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set list c.d.c.d" 0 "^$"

new "cli set ef"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set list e.f.e.f" 0 "^$"

new "cli set ab fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set list a&b&a&b" 255 "^CLI syntax error"

new "cli set ad fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set list a.b.c.d" 255 "^CLI syntax error"

new "cli validate"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang -l o validate" 0 "^$"

new "cli commit"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang -l o commit" 0 "^$"

new "netconf validate ok"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf set ab wrong"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><list><ip>a.b&amp; c.d</ip></list></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error>"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "cli enum value"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set status down" 0 "^$"

new "cli bits value"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set mbits create" 0 "^$"

#XXX No, cli cant assign two bit values
#new "cli bits two values"
#expectfn "$clixon_cli -1f $cfg -l o -y $fyang set mbits \"create read\"" 0 "^$"

new "netconf bits two values"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><mbits>create read</mbits></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "cli bits validate"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang validate" 0 "^$"

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
