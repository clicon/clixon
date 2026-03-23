#!/usr/bin/env bash
# Regression tests for XPath translate() in must/when expressions

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=test
dbdir=$(mktemp -d "$dir/${APPNAME}.xmldb.XXXXXX")
rundir=$(mktemp -d "$dir/${APPNAME}.run.XXXXXX")
chmod 777 "$dbdir" "$rundir"

cfg=$dir/conf_test_xpath_translate.xml
fyang=$dir/test-xpath-translate.yang

cat <<EOFCONF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>$dir/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>$dir/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$rundir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$rundir/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dbdir</CLICON_XMLDB_DIR>
</clixon-config>
EOFCONF

cat <<'EOFYANG' > $fyang
module test-xpath-translate {
  yang-version 1.1;
  namespace "urn:test:xpath-translate";
  prefix dxt;

  container profiles {
    list profile {
      key "name";
      leaf name {
        type string;
      }
      leaf profile-name {
        type string;
        must "not(translate(current()/text(),'Bad','bad') = 'bad-name')" {
          error-message "translate() rejects bad-name";
        }
      }
      leaf addr {
        type string;
        must "translate(current()/text(),'XYZ','xyz') != 'xyz@example.com'" {
          error-message "translate() rejects xyz@example.com";
        }
      }
    }
  }

  container network-instances {
    list ni {
      key "name";
      leaf name {
        type string;
      }
      leaf type {
        type string;
      }
      container type-dependent {
        when "translate(../type,'AB','ab') = 'a'";
        leaf enabled {
          type string;
        }
      }
    }
  }
}
EOFYANG

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

ns="urn:test:xpath-translate"

new "must translate valid values"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><profiles xmlns=\"$ns\"><profile><name>p1</name><profile-name>good-name</profile-name><addr>user@example.com</addr></profile></profiles></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate valid values"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "discard valid candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "must translate rejects profile-name"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><profiles xmlns=\"$ns\"><profile><name>p2</name><profile-name>Bad-name</profile-name><addr>good@example.com</addr></profile></profiles></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate profile-name translate failure"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<error-message>Failed MUST xpath 'not(translate(current()/text(),'Bad','bad') = 'bad-name')'"

new "discard bad profile-name"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "must translate rejects addr"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><profiles xmlns=\"$ns\"><profile><name>p3</name><profile-name>safe</profile-name><addr>XYZ@example.com</addr></profile></profiles></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate addr translate failure"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<error-message>Failed MUST xpath 'translate(current()/text(),'XYZ','xyz') != 'xyz@example.com''"

new "discard bad addr"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "when translate allows type A"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><network-instances xmlns=\"$ns\"><ni><name>n1</name><type>A</type><type-dependent><enabled>on</enabled></type-dependent></ni></network-instances></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate when translate allow"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "discard valid when"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "when translate rejects type C"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><network-instances xmlns=\"$ns\"><ni><name>n2</name><type>C</type><type-dependent><enabled>on</enabled></type-dependent></ni></network-instances></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate when translate failure"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<error-message>WHEN condition failed, xpath is translate(../type,'AB','ab') = 'a'"

new "discard bad when"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
