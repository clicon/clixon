#!/usr/bin/env bash
# Regression tests for demo-xpath-issues.yang exercising translate() and when expressions

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

mkdir -p /usr/local/var/demo && chown clicon:clicon /usr/local/var/demo

APPNAME=demo

cfg=$dir/conf_demo_xpath.xml
fyang=$dir/demo-xpath-issues.yang

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

cat <<'EOF' > $fyang
module demo-xpath-issues {
  yang-version 1.1;
  namespace "urn:demo:xpath-issues";
  prefix dxi;

  import ietf-yang-types { prefix yang; }

  description
    "Test: translate inside when";

  typedef demo-ref {
    type enumeration {
      enum A;
      enum B;
      enum C;
    }
  }

  container profiles {
    list profile {
      key "name";
      leaf name {
        type string;
      }
      leaf profile-name {
        type string;
        must "not(translate(current()/text(),'Bad','bad') = 'bad-name')" {
          error-message "translate() must rejects bad-name";
        }
      }
      leaf addr {
        type string;
        must "translate(current()/text(),'XYZ','xyz') != 'xyz@example.com'" {
          error-message "translate() must rejects xyz@example.com";
        }
      }
    }
  }

  container network-instances {
    list ni {
      key "name";
      leaf name { type string; }
      container config {
        leaf type {
          type demo-ref;
        }
      }
      container type-dependent {
        when "../config/type = 'A' or ../config/type = 'B'";
        leaf enabled-address-families {
          type string;
        }
      }
    }
  }

  container interfaces {
    list interface {
      key "name";
      leaf name { type string; }
      container ethernet {
        when "../dxi:state/dxi:type = 'ianaift:ethernetCsmacd'";
        leaf speed {
          type uint32;
        }
      }
      container state {
        leaf type {
          type string;
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
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

ns="urn:demo:xpath-issues"

new "profiles accept values that survive translate()"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><profiles xmlns=\"$ns\"><profile><name>p1</name><profile-name>good-name</profile-name><addr>user@example.com</addr></profile></profiles></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "profiles validate passes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "profiles discard"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "profile-name rejects translated bad-name"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><profiles xmlns=\"$ns\"><profile><name>p2</name><profile-name>Bad-name</profile-name><addr>good@example.com</addr></profile></profiles></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate reports profile-name translate error"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Failed MUST xpath 'not(translate(current()/text(),'Bad','bad') = 'bad-name')' translate() must rejects bad-name yang node: \"leaf profile-name\" with parent: \"list profile\" in file \"/var/tmp/./test_xpath_issues.sh/demo-xpath-issues.yang\" error-path: /profiles/profile[name=\"p2\"]/profile-name</error-message></rpc-error></rpc-reply>"

new "profiles discard after translate failure"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "addr rejects translated xyz@example.com"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><profiles xmlns=\"$ns\"><profile><name>p3</name><profile-name>safe</profile-name><addr>XYZ@example.com</addr></profile></profiles></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate reports addr translate error"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Failed MUST xpath 'translate(current()/text(),'XYZ','xyz') != 'xyz@example.com'' translate() must rejects xyz@example.com yang node: \"leaf addr\" with parent: \"list profile\" in file \"/var/tmp/./test_xpath_issues.sh/demo-xpath-issues.yang\" error-path: /profiles/profile[name=\"p3\"]/addr</error-message></rpc-error></rpc-reply>"

new "profiles discard after addr failure"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "type-dependent container allowed when type is A"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><network-instances xmlns=\"$ns\"><ni><name>blue</name><config><type>A</type></config><type-dependent><enabled-address-families>inet</enabled-address-families></type-dependent></ni></network-instances></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "network-instances validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "discard network-instances"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "type-dependent container rejected when type mismatches"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><network-instances xmlns=\"$ns\"><ni><name>red</name><config><type>C</type></config><type-dependent><enabled-address-families>inet</enabled-address-families></type-dependent></ni></network-instances></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate catches type-dependent when expression"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>WHEN condition failed, xpath is ../config/type = 'A' or ../config/type = 'B' yang node: \"container type-dependent\" with parent: \"list ni\" in file \"/var/tmp/./test_xpath_issues.sh/demo-xpath-issues.yang\" error-path: /network-instances/ni[name=\"red\"]/type-dependent</error-message></rpc-error></rpc-reply>"

new "discard after invalid type-dependent"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "ethernet container allowed when state type matches"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"$ns\"><interface><name>eth0</name><state><type>ianaift:ethernetCsmacd</type></state><ethernet><speed>1000</speed></ethernet></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "interfaces validate ok"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "discard valid interface"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "ethernet container rejected when state type mismatches"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interfaces xmlns=\"$ns\"><interface><name>eth1</name><state><type>ianaift:atm</type></state><ethernet><speed>100</speed></ethernet></interface></interfaces></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate catches ethernet when expression"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>WHEN condition failed, xpath is ../dxi:state/dxi:type = 'ianaift:ethernetCsmacd' yang node: \"container ethernet\" with parent: \"list interface\" in file \"/var/tmp/./test_xpath_issues.sh/demo-xpath-issues.yang\" error-path: /interfaces/interface[name=\"eth1\"]/ethernet</error-message></rpc-error></rpc-reply>"

new "discard invalid interface"
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
