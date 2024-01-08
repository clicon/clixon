#!/usr/bin/env bash
# Yang list / leaf-list min/max-element tests.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
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
module $APPNAME{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  container c{
    presence true;
    list a0{
      key k;
      leaf k {
        type string;
      }
      min-elements 0;
      max-elements "unbounded";
    }
    list a1{
      key k;
      leaf k {
        type string;
      }
      description "There must be at least one of these";
      min-elements 1;
      max-elements 2;
    }
    leaf-list b0{
      type string;
      min-elements 0;
      max-elements "unbounded";
    }
    leaf-list b1{
      description "There must be at least one of these";
      type string;
      min-elements 1;
      max-elements 2;
    }
  }
  container c2{
    description "with choices";
    choice ch1{
      case x{
        list a1{
          key k;
          leaf k {
            type string;
          }
          min-elements 1;
          max-elements 2;
        }
      }
      case y{
        list a2{
          key k;
          leaf k {
            type string;
          }
          min-elements 0;
          max-elements 3;
        }
      }
    }
    choice ch2{
      leaf-list b1{
        type string;
        min-elements 1;
        max-elements 2;
      }
    }
  }
  leaf-list b3{
     description "top-level";
     type int32;
     min-elements 1;
     max-elements 2;
  }
  container c3{
    list b2{
      description "RFC7950 7.7.5 : it is enforced if the ancestor node exists.";
      key kb;
      leaf kb {
        type string;
      }
      container b2c {
        leaf-list b2ll{
          min-elements 1;
          type string;
        }
      }
      leaf-list b3ll{
          type string;
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
    new "start backend -s init -f $cfg"
    # start new backend
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "minmax: minimal: 1x a1,b1 (should be [1:2]"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\">
  <a1><k>0</k></a1>
  <b1>0</b1>
</c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: minimal validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: maximal: 2x a1,b1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\"><a0><k>0</k></a0><a0><k>1</k></a0><a0><k>unbounded</k></a0><a1><k>0</k></a1><a1><k>1</k></a1><b0>0</b0><b0>1</b0><b0>unbounded</b0><b1>1</b1><b1>0</b1><b0>1</b0></c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: replace with 0x a1,b1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\"/></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: validate should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-few-elements</error-app-tag><error-severity>error</error-severity><error-path>/c/a1</error-path></rpc-error></rpc-reply>"

new "minmax: no list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\"><b1>0</b1></c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: validate should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-few-elements</error-app-tag><error-severity>error</error-severity><error-path>/c/a1</error-path></rpc-error></rpc-reply>"

new "minmax: no leaf-list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\"><a1><k>0</k></a1></c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: validate should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-few-elements</error-app-tag><error-severity>error</error-severity><error-path>/c/b1</error-path></rpc-error></rpc-reply>"

new "minmax: Too large list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\"><a1><k>0</k></a1><a1><k>1</k></a1><a1><k>2</k></a1><b1>0</b1></c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: validate should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>/c/a1</error-path></rpc-error></rpc-reply>"

new "minmax: Too large leaf-list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\"><a1><k>0</k></a1><b1>0</b1><b1>1</b1><b1>2</b1></c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: validate should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>/c/b1</error-path></rpc-error></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# With choice c1
new "minmax choice: minimal"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c2 xmlns=\"urn:example:clixon\">
  <a1><k>0</k></a1>
  <b1>0</b1>
</c2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax choice: minimal validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax choice: many a2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c2 xmlns=\"urn:example:clixon\">
  <a2><k>0</k></a2>
  <a2><k>1</k></a2>
  <a2><k>2</k></a2>
  <b1>0</b1>
</c2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax choice: many a2 validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax choice: too many a1 should fail"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c2 xmlns=\"urn:example:clixon\">
  <a1><k>0</k></a1>
  <a1><k>1</k></a1>
  <a1><k>2</k></a1>
  <b1>0</b1>
</c2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>/rpc/edit-config/config/c2/a1</error-path></rpc-error></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# top config level
new "minmax top level"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>
   <b3 xmlns=\"urn:example:clixon\">0</b3>
   <b3 xmlns=\"urn:example:clixon\">1</b3>
</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax top level ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax top level too many"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>
   <b3 xmlns=\"urn:example:clixon\">0</b3>
   <b3 xmlns=\"urn:example:clixon\">1</b3>
   <b3 xmlns=\"urn:example:clixon\">2</b3>
</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>/rpc/edit-config/config/b3</error-path></rpc-error></rpc-reply>"

new "minmax top level too many should fail"
#expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-many-elements</error-app-tag><error-severity>error</error-severity><error-path>/b3</error-path></rpc-error></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Above only tests on candidate -> empty running
# Also need to do commit tests when running has elements and candidate has fewer

new "Set maximal: 2x a1,b1"
expecteof_netconf "$clixon_netconf -qf $cfg -D 1" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config><c xmlns=\"urn:example:clixon\"><a1><k>0</k></a1><a1><k>1</k></a1><b1>1</b1><b1>0</b1></c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: delete to minimal: 1x a1,b1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config><c xmlns=\"urn:example:clixon\" xmlns:nc=\"${BASENS}\"><a1 nc:operation=\"delete\"><k>1</k></a1><b1 nc:operation=\"delete\">1</b1></c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: commit minimal list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: delete to no list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config><c xmlns=\"urn:example:clixon\" xmlns:nc=\"${BASENS}\"><a1 nc:operation=\"delete\"><k>0</k></a1><b1 nc:operation=\"delete\">0</b1></c></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: validate should fail empty list"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-few-elements</error-app-tag><error-severity>error</error-severity><error-path>/c/a1</error-path></rpc-error></rpc-reply>"

new "delete c"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config><c xmlns=\"urn:example:clixon\" xmlns:nc=\"${BASENS}\" nc:operation=\"delete\"/></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# <b2><kb>0</kb></b2>
new "add empty list entry with a min-element leaf within a non-presence container"
expecteof_netconf "$clixon_netconf -qf $cfg -D 1 -l s" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS $DEFAULTNS><edit-config><target><candidate/></target><config><c3 xmlns=\"urn:example:clixon\"><b2><kb>0</kb></b2></c3></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: validate should fail, there should be a b2ll trailing"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-few-elements</error-app-tag><error-severity>error</error-severity><error-path>/c3/b2\[kb=\"0\"\]/b2ll</error-path></rpc-error></rpc-reply>" ""

# <b2><kb>0</kb><b3ll>42</b3ll></b2>
new "add b3ll after missing b2ll"
expecteof_netconf "$clixon_netconf -qf $cfg -D 1 -l s" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS $DEFAULTNS><edit-config><target><candidate/></target><config><c3 xmlns=\"urn:example:clixon\"><b2><kb>0</kb><b3ll>42</b3ll></b2></c3></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "minmax: validate should fail, there should be a b2ll before b3ll"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>protocol</error-type><error-tag>operation-failed</error-tag><error-app-tag>too-few-elements</error-app-tag><error-severity>error</error-severity><error-path>/c3/b2\[kb=\"0\"\]/b2ll</error-path></rpc-error></rpc-reply>" ""

# Positive tests
# <b2><kb>0</kb><b2c><b2ll>71</b2ll></b2c><b3ll>42</b3ll></b2>
new "add b2ll to satisfy min-elements, gap"
expecteof_netconf "$clixon_netconf -qf $cfg -D 1 -l s" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS $DEFAULTNS><edit-config><target><candidate/></target><config><c3 xmlns=\"urn:example:clixon\"><b2><kb>0</kb><b2c><b2ll>71</b2ll></b2c></b2></c3></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate expect OK xxx"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# <b2><kb>0</kb><b2c><b2ll>71</b2ll></b2c></b2>
new "delete b3ll, empty"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config><c3 xmlns=\"urn:example:clixon\" xmlns:nc=\"${BASENS}\"><b2><kb>0</kb><b3ll nc:operation=\"delete\">42</b3ll></b2></c3></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate expect OK"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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
