#!/bin/bash
# Advanced union types and generated code
# and enum w values
# @see test_type.sh  ONLY DIFFERENCE IS db-cache is OFF here

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/type.yang
fyang2=$dir/example2.yang
fyang3=$dir/example3.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_CACHE>false</CLICON_XMLDB_CACHE>
</clixon-config>
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
   leaf num1 {
       type int32 {
       range "1";
      }
   }
   leaf num2 { /* range and blanks */
       type int32 {
         range " 4 .. 4000 ";
      }
   }
   leaf num3 {
       type uint8 {
         range "min..max";
      }
   }
   leaf num4 { 
       type uint8 {
         range "1..2 |  42..50";
      }
   }
   leaf dec { 
       /* For test of multiple ranges with decimal64. More than 2, single range*/
       type decimal64 {
         fraction-digits 3;
         range "-3.5..-2.5 | 0.0 | 10.0..20.0";
      }
   }
   leaf len1 {
       type string {
       length "2";
      }
   }
   leaf len2 {
       type string {
         length " 4 .. 4000 ";
      }
   }
   leaf len3 {
       type string {
         length "min..max";
      }
   }
   leaf len4 {
       type string {
         length "2  ..  3 |  20..29";
      }
   }
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
  leaf digit4{
     type string {
         pattern '\d{4}';
       }
  }
  leaf word4{
     type string {
         pattern '\w{4}';
       }
  }
  leaf minus{
      description "Problem with minus";
      type string{
         pattern '[a-zA-Z_][a-zA-Z0-9_\-.]*';
      }
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
    start_backend -s init -f $cfg -y $fyang

    new "waiting"
    sleep $RCWAIT
fi

new "cli set transitive string. type is alpha followed by number and is defined in three levels of modules"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c talle x99" 0 "^$"

new "cli set transitive string error. Wrong type"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set c talle 9xx" 255 "^$"

new "netconf set transitive string error"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><c xmlns="urn:example:clixon"><talle>9xx</talle></c></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>"

new "netconf validate should fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>talle</bad-element></error-info><error-severity>error</error-severity><error-message>regexp match fail: "9xx" does not match \[a-z\]\[0-9\]\*</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "cli set transitive union int (ulle should accept 4.44|bounded|unbounded)"
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
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><c xmlns="urn:example:clixon"><ulle>55</ulle></c></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>"

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
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><list xmlns="urn:example:clixon"><ip>a.b&amp; c.d</ip></list></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

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
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><mbits xmlns="urn:example:clixon">create read</mbits></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "cli bits validate"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang validate" 0 "^$"

#-------- num1 single range (1)

new "cli range test num1 1 OK"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num1 1" 0 "^$"

#new "cli range test num1 -100 ok" # XXX -/minus cant be given as argv
#expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num1 \-100" 0 "^$"

new "cli range test num1 2 error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num1 2" 255 "^$"

new "netconf range set num1 -1"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><num1 xmlns="urn:example:clixon">-1</num1></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate num1 -1 wrong"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>num1</bad-element></error-info><error-severity>error</error-severity><error-message>Number out of range: -1</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#-------- num2 range and blanks

new "cli range test num2 3 error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num2 3" 255 "^$"

new "cli range test num2 1000 ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num2 1000" 0 "^$"

new "cli range test num2 5000 error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num2 5000" 255 "^$"

new "netconf range set num2 3 fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><num2 xmlns="urn:example:clixon">3</num2></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate num2 3 fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>num2</bad-element></error-info><error-severity>error</error-severity><error-message>Number out of range: 3</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf range set num2 1000 ok"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><num2 xmlns="urn:example:clixon">1000</num2></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate num2 1000 ok"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf range set num2 5000 fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><num2 xmlns="urn:example:clixon">5000</num2></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate num2 5000 fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>num2</bad-element></error-info><error-severity>error</error-severity><error-message>Number out of range: 5000</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#-------- num3 min max range

new "cli range test num3 42 ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num3 42" 0 "^$"

new "cli range test num3 260 fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num3 260" 255 "^$"

new "cli range test num3 -1 fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num3 -1" 255 "^$"

new "netconf range set num3 260 fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><num3 xmlns="urn:example:clixon">260</num3></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate num3 260 fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>num3</bad-element></error-info><error-severity>error</error-severity><error-message>260 is out of range(type is uint8)</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#-------- num4 multiple ranges 1..2 |  42..50

new "cli range test num4 multiple 0 fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num4 0" 255 "^$"

new "cli range test num4 multiple 2 ok"
expectfn "$clixon_cli -1f $cfg -l e -y $fyang set num4 2" 0 "^$"

new "cli range test num4 multiple 20 fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num4 20" 255 "^$"

new "cli range test num4 multiple 42 ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num4 42" 0 "^$"

new "cli range test num4 multiple 99 fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num4 99" 255 "^$"

new "netconf range set num4 multiple 2"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><num4 xmlns="urn:example:clixon">42</num4></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate num4 OK"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf range set num4 multiple 20"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><num4 xmlns="urn:example:clixon">42</num4></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate num4 fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf range set num4 multiple 42"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><num4 xmlns="urn:example:clixon">42</num4></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate num4 fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#-------- dec64 multiple ranges -3.5..-2.5 | 0.0 | 10.0..20.0
# XXX how to enter negative numbers in bash string and cli -1?
new "cli range dec64 multiple 0 ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set dec 0" 0 "^$"

new "cli range dec64 multiple 0.1 fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set num4 0.1" 255 "^$"

new "cli range dec64 multiple 15.0 ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set dec 15.0" 0 "^$"

new "cli range dec64 multiple 30.0 fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set dec 30.0" 255 "^$"

new "dec64 discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Same with netconf
new "netconf range dec64 -3.59"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><dec xmlns="urn:example:clixon">-3.59</dec></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf range dec64 -3.59 validate fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>dec</bad-element></error-info><error-severity>error</error-severity><error-message>Number out of range'

new "netconf range dec64 -3.5"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><dec xmlns="urn:example:clixon">-3.500</dec></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf range dec64 -3.5 validate ok"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf range dec64 -2"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><dec xmlns="urn:example:clixon">-2</dec></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf range dec64 -2 validate fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>dec</bad-element></error-info><error-severity>error</error-severity><error-message>Number out of range'

new "netconf range dec64 -0.001"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><dec xmlns="urn:example:clixon">-0.001</dec></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf range dec64 -0.001 validate fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>dec</bad-element></error-info><error-severity>error</error-severity><error-message>Number out of range'

new "netconf range dec64 0.0"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><dec xmlns="urn:example:clixon">0.0</dec></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf range dec64 0.0 validate ok"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><ok/></rpc-reply>]]>]]>$'

new "netconf range dec64 +0.001"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><dec xmlns="urn:example:clixon">+0.001</dec></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf range dec64 +0.001 validate fail"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>dec</bad-element></error-info><error-severity>error</error-severity><error-message>Number out of range'

#----------------string ranges---------------------
#-------- len1 single range (2)
new "cli length test len1 1 fail"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len1 x" 255 "^$"

new "cli length test len1 2 OK"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len1 xy" 0 "^$"

new "cli length test len1 3 error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len1 hej" 255 "^$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf length set len1 1"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><len1 xmlns="urn:example:clixon">x</len1></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate len1 1 wrong"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>len1</bad-element></error-info><error-severity>error</error-severity><error-message>string length out of range: 1</error-message></rpc-error></rpc-reply>]]>]]>$'

#-------- len2 range and blanks

new "cli length test len2 3 error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len2 ab" 255 "^$"

new "cli length test len2 42 ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len2 hejhophdsakjhkjsadhkjsahdkjsad" 0 "^$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#-------- len3 min max range

new "cli range ptest len3 42 ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len3 hsakjdhkjsahdkjsahdksahdksajdhsakjhd" 0 "^$"

#-------- len4 multiple ranges 2..3 |  20-29
new "cli length test len4 1 error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len4 a" 255 "^$"

new "cli length test len4 2 ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len4 ab" 0 "^$"

new "cli length test len4 10 error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len4 abcdefghij" 255 "^$"

new "cli length test len4 20 ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len4 abcdefghijabcdefghija" 0 "^$"

new "cli length test len4 30 error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set len4 abcdefghijabcdefghijabcdefghij" 255 "^$"

# XSD schema -> POSIX ECE translation
new "cli yang pattern \d ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set digit4 0123" 0 "^$"

new "cli yang pattern \d error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set digit4 01b2" 255 "^$"

new "cli yang pattern \w ok"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set word4 abc9" 0 "^$"

new "cli yang pattern \w error"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set word4 ab%3" 255 "^$"

new "netconf pattern \w"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><word4 xmlns="urn:example:clixon">aXG9</word4></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf pattern \w valid"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf pattern \w error"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><word4 xmlns="urn:example:clixon">ab%d3</word4></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf pattern \w valid"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>word4</bad-element></error-info><error-severity>error</error-severity><error-message>regexp match fail: "ab%d3" does not match \\w{4}</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"


#------ minus

new "type with minus"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><minus xmlns="urn:example:clixon">my-name</minus></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "validate minus"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#new "cli type with minus"
#expectfn "$clixon_cli -1f $cfg -l o -y $fyang set name my-name" 0 "^$"

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
stop_backend -f $cfg

rm -rf $dir
