#!/usr/bin/env bash
# Yang leafref + union test (+ identitytref)
# See eg https://github.com/clicon/clixon/issues/277
# See also https://github.com/clicon/clixon/issues/388
# See also https://github.com/clicon/clixon/issues/498

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
module example{
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    identity crypto {
         description
           "Base identity from which all crypto algorithms
            are derived.";
    }
    identity des {
         base "crypto";
         description "DES crypto algorithm.";
    }
    identity des3 {
         base "crypto";
         description "Triple DES crypto algorithm.";
    }
    identity airplane;
    identity boeing {
         base "airplane";
    }
    identity saab {
         base "airplane";
    }
    typedef ref1 {
      type leafref {
        path "../x";
          require-instance true;
        }
    }
    typedef ref2 {
      type leafref {
        path "../y";
        require-instance true;
      }
    }
    /* Issue #498: typedef union of string pattern + leafref */
    typedef reftype {
        type union {
            type string {
                pattern 'default';
            }
            type leafref {
                path "../x";
                require-instance true;
            }
        }
    }
    container c {
       leaf x {
          type string;
       }
       leaf y {
          type string;
       }
       leaf z {
         description "leafref union";
          type union {
             type leafref {
                path "../x";
                require-instance true;
             }
             type leafref {
                path "../y";
                require-instance true;
            }
         }
      }
      leaf zdecl {
         description "leafref union using declared types";
          type union {
             type ref1;
             type ref2;
          }
      }
      leaf w {
         description "idref union";
         type union {
             type identityref {
                 base crypto;
             }
             type identityref {
                 base airplane;
             }
         }
      }
      leaf u {
         description "Union mix of idref and leafref";
         type union {
             type identityref {
                 base crypto;
             }
             type leafref {
                path "../x";
                require-instance true;
            }
         }
      }
      leaf v {
         description "Union typedef with string pattern + leafref (issue #498)";
         type reftype;
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

new "netconf set x,y leafs"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><x>42</x><y>99</y></c></config><default-operation>merge</default-operation> </edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit x,y"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set union 42"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><z>42</z></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf check config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:clixon\"><x>42</x><y>99</y><z>42</z></c></data></rpc-reply>"

new "netconf set union 66"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><z>66</z></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate not ok 1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>instance-required</error-app-tag><error-path>../y</error-path><error-info><z>66</z></error-info><error-severity>error</error-severity>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set union id saab"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><w>ex:saab</w></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set union idref zzz"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><w>ex:zzz</w></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate idref not ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Identityref validation failed" ""

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set union id des"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><u>ex:des</u></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set union x=42"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><u>42</u></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set union 99"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><u>99</u></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate not ok 2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>instance-required</error-app-tag><error-path>../x</error-path><error-info><u>99</u></error-info><error-severity>error</error-severity>" ""

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Issue #388: typedef'd leafrefs in union (zdecl tests)
new "netconf set zdecl=42 (matches ref1 -> x)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><zdecl>42</zdecl></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate zdecl=42 ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set zdecl=99 (matches ref2 -> y)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><zdecl>99</zdecl></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate zdecl=99 ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set zdecl=66 (matches neither ref1 nor ref2)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><zdecl>66</zdecl></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate zdecl=66 not ok (issue #388)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>instance-required</error-app-tag>" ""

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Issue #498: union typedef of string pattern + leafref
new "netconf set v=42 (matches leafref -> x)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><v>42</v></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate v=42 ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set v=default (matches string pattern)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><v>default</v></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate v=default ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf set v=66 (matches neither pattern nor leafref)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><v>66</v></c></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate v=66 not ok (issue #498)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error>" ""

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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
