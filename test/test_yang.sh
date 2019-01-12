#!/bin/bash
# Yang specifics: multi-keys and empty type
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyang=$dir/$APPNAME.yang
fsubmod=$dir/example-types.yang
fyangerr=$dir/err.yang

#  <CLICON_YANG_DIR>/usr/local/share/$APPNAME/yang</CLICON_YANG_DIR>
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>$APPNAME</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</config>
EOF

cat <<EOF > $fyang
module $APPNAME{
   yang-version 1.1;
   prefix ex;
   namespace "urn:example:clixon";
   include example-types;
   extension c-define {
      description "Example from RFC 6020";
      argument "name";
   }
   ex:c-define "MY_INTERFACES";
   container x {
    list y {
      key "a b c";
      leaf a {
        type string;
      }
      leaf b {
        type string;
      }
      leaf c {
        type string;
      }   
      leaf val {
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
  list mylist{ /* uses submodule */
         key x;
         leaf x{
           type string;
         }
         uses ex:subm-group;
  }
}
EOF

# Submodule Example from rfc7950 sec 7.2.3
cat <<EOF > $fsubmod
submodule example-types {
       yang-version 1.1;
       belongs-to $APPNAME {
         prefix "sys";
       }
       import ietf-yang-types {
         prefix "yang";
       }
       organization "Example Inc.";
       contact         "Joe L. User";
       description
         "This submodule defines common Example types.";
       revision "2007-06-09" {
         description "Initial revision.";
       }
      grouping subm-group {
        description "Defined in submodule";
        container subm-container{
          leaf subm-leaf{
            type string;
          }
        }
      }
}
EOF

# This yang definition uses an extension which is not defined. Error when loading
cat <<EOF > $fyangerr
module $APPNAME{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   extension c-define {
      description "Example from RFC 6020";
      argument "name";
   }
   ex:not-defined ARGUMENT;
}
EOF

new "test params: -f $cfg -y $fyang"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg -y $fyang"
    sudo $clixon_backend -s init -f $cfg -y $fyang -D $DBG
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "cli defined extension"
expectfn "$clixon_cli -1f $cfg -y $fyang show version" 0 "3."

new "empty values in leaf-list"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><f><e>a</e></f></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "empty values in leaf-list2"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><f><e/></f></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get config"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><x xmlns="urn:example:clixon"><f><e/><e>a</e></f></x></data></rpc-reply>]]>]]>$'

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"


#new "cli not defined extension"
#new "netconf not defined extension"
#expecteof "$clixon_netconf -qf $cfg -l o" 0 "$YANG" "Extension ex:not-defined not found"
# This text yields an error, but the test cannot detect the error message yet
#expectfn "$clixon_cli -1f $cfg -y $fyangerr show version" 0 "Yang error: Extension ex:not-defined not found"

new "netconf schema resource, RFC 7895"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get><filter type="xpath" select="modules-state/module" xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library"/></get></rpc>]]>]]>' '<module><name>ietf-yang-types</name><revision>2013-07-15</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-yang-types</namespace><conformance-type>implement</conformance-type></module>'

new "netconf edit config"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><y><a>1</a><b>2</b><c>5</c><val>one</val></y><d/></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# text empty type in running
new "netconf commit 2nd"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get config xpath"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/y[a=1][b=2][c=5]\"/></get-config></rpc>]]>]]>" '^<rpc-reply><data><x xmlns="urn:example:clixon"><y><a>1</a><b>2</b><c>5</c><val>one</val></y></x></data></rpc-reply>]]>]]>$'

new "netconf edit leaf-list"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><f><e>hej</e><e>hopp</e></f></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get leaf-list"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/x/f/e"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><x xmlns="urn:example:clixon"><f><e>hej</e><e>hopp</e></f></x></data></rpc-reply>]]>]]>$'

new "netconf get leaf-list path"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/x/f[e='hej']\"/></get-config></rpc>]]>]]>" "^<rpc-reply><data><x xmlns=\"urn:example:clixon\"><f><e>hej</e><e>hopp</e></f></x></data></rpc-reply>]]>]]>$"

new "netconf get (should be some)"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get><filter type=\"xpath\" select=\"/\"/></get></rpc>]]>]]>" '^<rpc-reply><data><x xmlns="urn:example:clixon"><y><a>1</a><b>2</b><c>5</c><val>one</val></y><d/></x>'

new "cli set leaf-list"
expectfn "$clixon_cli -1f $cfg -y $fyang set x f e foo" 0 ""

new "cli show leaf-list"
expectfn "$clixon_cli -1f $cfg -y $fyang show xpath /x/f/e" 0 "<e>foo</e>"

new "netconf set state data (not allowed)"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><state xmlns="urn:example:clixon"><op>42</op></state></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>protocol</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>State data not allowed</error-message></rpc-error></rpc-reply>]]>]]>$'

new "netconf set presence and not present"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><nopresence/><presence/></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get presence only"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/x/presence"/></get-config></rpc>]]>]]>' '^<rpc-reply><data><x xmlns="urn:example:clixon"><presence/></x></data></rpc-reply>]]>]]>$'

new "netconf get presence only"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get-config><source><candidate/></source><filter type="xpath" select="/x/nopresence"/></get-config></rpc>]]>]]>' "^<rpc-reply><data/></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf anyxml"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><any><foo><bar a="nisse"/></foo></any></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate anyxml"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf delete candidate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation="delete"/></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Check 3-keys
new "netconf add one 3-key entry"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><y><a>1</a><b>1</b><c>1</c><val>one</val></y></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf check add one 3-key"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '<rpc-reply><data><x xmlns="urn:example:clixon"><y><a>1</a><b>1</b><c>1</c><val>one</val></y></x></data></rpc-reply>]]>]]>'

new "netconf add another (with same 1st key)"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><y><a>1</a><b>2</b><c>1</c><val>two</val></y></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf check add another"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '<rpc-reply><data><x xmlns="urn:example:clixon"><y><a>1</a><b>1</b><c>1</c><val>one</val></y><y><a>1</a><b>2</b><c>1</c><val>two</val></y></x></data></rpc-reply>]]>]]>'

new "netconf replace first"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><y><a>1</a><b>1</b><c>1</c><val>replace</val></y></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf check replace"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '<rpc-reply><data><x xmlns="urn:example:clixon"><y><a>1</a><b>1</b><c>1</c><val>replace</val></y><y><a>1</a><b>2</b><c>1</c><val>two</val></y></x></data></rpc-reply>]]>]]>'

new "netconf delete first"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon"><y operation="remove"><a>1</a><b>1</b><c>1</c></y></x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf check delete"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '<rpc-reply><data><x xmlns="urn:example:clixon"><y><a>1</a><b>2</b><c>1</c><val>two</val></y></x></data></rpc-reply>]]>]]>'

# clear db for next test
new "netconf delete candidate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation="delete"/></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf commit empty candidate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconfig config submodule"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><mylist xmlns="urn:example:clixon"><x>a</x><subm-container><subm-leaf>foo</subm-leaf></subm-container></mylist></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf submodule get config"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' '^<rpc-reply><data><mylist xmlns="urn:example:clixon"><x>a</x><subm-container><subm-leaf>foo</subm-leaf></subm-container></mylist></data></rpc-reply>]]>]]>$'

new "netconf submodule validate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf submodule discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

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
sudo pkill -u root -f clixon_backend

rm -rf $dir
