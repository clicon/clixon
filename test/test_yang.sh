#!/usr/bin/env bash
# Yang test: multi-keys and empty type

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = "$0" ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/$APPNAME.yang
fsubmod=$dir/example-types.yang
fyangerr=$dir/err.yang
clispec=$dir/clispec
test -d $clispec || mkdir $clispec

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>$clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module $APPNAME{
   yang-version 1.1;
   prefix ex;
   namespace "urn:example:clixon";
   include example-types;
    revision 2020-12-01 {
        description "Added table/parameter/value as the primary data example";
    }
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

cat <<EOF > $clispec/example.cli
CLICON_MODE="example";
CLICON_PROMPT="cli> ";

# Reference generated data model
set @datamodel, cli_set();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_config("candidate", "text");
    version("Show version"), cli_show_version("candidate", "text", "/");
    xpath("Show configuration") <xpath:string>("XPATH expression") <ns:string>("Namespace"), show_conf_xpath("candidate");
    yang("Show yang specs"), show_yang(); {
        example("Show example yang spec"), show_yang("example");
    }              
}
EOF

new "test params: -f $cfg"

if [ "$BE" -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf "$cfg"
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f "$cfg"
fi

new "wait backend"
wait_backend

new "cli show version"
expectpart "$($clixon_cli -1f $cfg show version)" 0 "${CLIXON_VERSION}"

new "cli show yang example"
expectpart "$($clixon_cli -1f $cfg show yang example)" 0 "revision 2020-12-01" "Added table/parameter/value as the primary data example"

new "empty values in leaf-list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><f><e>a</e></f></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "empty values in leaf-list2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><f><e/></f></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><f><e/><e>a</e></f></x></data></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

#new "cli not defined extension"
#new "netconf not defined extension"
#expecteof_netconf "$clixon_netconf -qf $cfg -l o" 0 "$YANG" "Extension ex:not-defined not found"
# This text yields an error, but the test cannot detect the error message yet
#expectpart "$($clixon_cli -1f $cfg -y $fyangerr show version)" 0 "Yang error: Extension ex:not-defined not found"

new "netconf schema resource, RFC 8525"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"yanglib:yang-library/yanglib:module-set[yanglib:name='default']/yanglib:module\" xmlns:yanglib=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\"/></get></rpc>" "<module><name>ietf-yang-types</name><revision>2013-07-15</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-yang-types</namespace></module>"

new "netconf edit config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>1</a><b>2</b><c>5</c><val>one</val></y><d/></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# text empty type in running
new "netconf commit 2nd"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get config xpath"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/c:x/c:y[c:a=1][c:b=2][c:c=5]\" xmlns:c=\"urn:example:clixon\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><y><a>1</a><b>2</b><c>5</c><val>one</val></y></x></data></rpc-reply>"

new "netconf edit leaf-list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><f><e>hej</e><e>hopp</e></f></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get leaf-list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/c:x/c:f/c:e\" xmlns:c=\"urn:example:clixon\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><f><e>hej</e><e>hopp</e></f></x></data></rpc-reply>"

new "netconf get leaf-list path"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/c:x/c:f[c:e='hej']\" xmlns:c=\"urn:example:clixon\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><f><e>hej</e><e>hopp</e></f></x></data></rpc-reply>"

new "netconf get (should be some)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/\"/></get></rpc>" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><y><a>1</a><b>2</b><c>5</c><val>one</val></y><d/></x>" ""

new "cli set leaf-list"
expectpart "$($clixon_cli -1f $cfg set x f e foo)" 0 ""

new "cli show leaf-list"
expectpart "$($clixon_cli -1f $cfg show xpath /x/f/e urn:example:clixon)" 0 "<e>foo</e>"

new "netconf set state data (not allowed)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><state xmlns=\"urn:example:clixon\"><op>42</op></state></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>state</bad-element></error-info><error-severity>error</error-severity><error-message>module example: state data node unexpected</error-message></rpc-error></rpc-reply>"

new "netconf set presence and not present"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><nopresence/><presence/></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get presence only"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/c:x/c:presence\" xmlns:c=\"urn:example:clixon\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><presence/></x></data></rpc-reply>"

new "netconf get presence only"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/c:x/c:nopresence\" xmlns:c=\"urn:example:clixon\"/></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf anyxml"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><any><foo><bar a='nisse'/></foo></any></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf validate anyxml"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf delete candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation=\"delete\"/></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Check 3-keys
new "netconf add one 3-key entry"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>1</a><b>1</b><c>1</c><val>one</val></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf check add one 3-key"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><y><a>1</a><b>1</b><c>1</c><val>one</val></y></x></data></rpc-reply>"

new "netconf add another (with same 1st key)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>1</a><b>2</b><c>1</c><val>two</val></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf check add another"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><y><a>1</a><b>1</b><c>1</c><val>one</val></y><y><a>1</a><b>2</b><c>1</c><val>two</val></y></x></data></rpc-reply>"

new "netconf replace first"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\"><y><a>1</a><b>1</b><c>1</c><val>replace</val></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf check replace"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><y><a>1</a><b>1</b><c>1</c><val>replace</val></y><y><a>1</a><b>2</b><c>1</c><val>two</val></y></x></data></rpc-reply>"

new "netconf delete first"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><x xmlns=\"urn:example:clixon\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"><y nc:operation=\"remove\"><a>1</a><b>1</b><c>1</c></y></x></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf check delete"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><x xmlns=\"urn:example:clixon\"><y><a>1</a><b>2</b><c>1</c><val>two</val></y></x></data></rpc-reply>"

# clear db for next test
new "netconf delete candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config operation=\"delete\"/></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit empty candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconfig config submodule"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><mylist xmlns=\"urn:example:clixon\"><x>a</x><subm-container><subm-leaf>foo</subm-leaf></subm-container></mylist></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf submodule get config"
expecteof_netconf "$clixon_netconf -qf $cfg -D 1 -l s" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><mylist xmlns=\"urn:example:clixon\"><x>a</x><subm-container><subm-leaf>foo</subm-leaf></subm-container></mylist></data></rpc-reply>"

new "netconf submodule validate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf submodule discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    # kill backend
    stop_backend -f "$cfg"
fi

rm -rf "$dir"

new "endtest"
endtest
