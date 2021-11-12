#!/usr/bin/env bash
# Yang leafref + union test (+ identitytref)
# See eg https://github.com/clicon/clixon/issues/277

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/leafref.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
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
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><x>42</x><y>99</y></c></config><default-operation>merge</default-operation> </edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit x,y"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf set union 42"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><z>42</z></c></config><default-operation>none</default-operation></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf check config"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:clixon\"><x>42</x><y>99</y><z>42</z></c></data></rpc-reply>]]>]]>$"

new "netconf set union 66"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><z>66</z></c></config><default-operation>none</default-operation></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate not ok"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>66</bad-element></error-info><error-severity>error</error-severity><error-message>Leafref validation failed: No leaf 66 matching path ../y"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf set union id saab"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><w>ex:saab</w></c></config><default-operation>none</default-operation></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"
new "netconf validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf set union idref zzz"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><w>ex:zzz</w></c></config><default-operation>none</default-operation></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate idref not ok"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Identityref validation failed"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf set union id des"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><u>ex:des</u></c></config><default-operation>none</default-operation></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf set union x=42"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><u>42</u></c></config><default-operation>none</default-operation></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate ok"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf set union 99"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><c xmlns=\"urn:example:clixon\"><u>99</u></c></config><default-operation>none</default-operation></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate not ok"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>99</bad-element></error-info><error-severity>error</error-severity><error-message>Leafref validation failed"

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
