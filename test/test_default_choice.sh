#!/usr/bin/env bash
# Tests of defaults in choices.
# From RFC7950 Sec 7.9.3
# 1. Default case,  the default if no child nodes from any of the choice's cases exist
# 2. Default for child nodes under a case are only used if one of the nodes under that case
#    is present 
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/choice.xml
clidir=$dir/cli
fyang=$dir/transfer.yang

test -d ${clidir} || rm -rf ${clidir}
mkdir $clidir

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# See example in RFC 7950 Sec 7.9.3
cat <<EOF > $fyang
module transfer{
  yang-version 1.1;
  namespace "urn:example:transfer";
  prefix tr;
  grouping transfer-container {
    description "Example from RFC 7950 Sec 7.9.3";
    container transfer {
      choice how {
        default interval;
        case interval {
          leaf interval {
            type uint16;
            units minutes;
            default 30;
          }
        }
        case daily {
          leaf daily {
            type empty;
          }
          leaf time-of-day {
            type string;
            units 24-hour-clock;
            default "01.00";
          }
        }
        case manual {
          leaf manual {
            type empty;
          }
        }
      }
    }
  }
  uses transfer-container;
  /* Same but within list */
  list li{
    key x;
    leaf x {
      type int32;
    }
    uses transfer-container;
  }
}
EOF

cat <<EOF > $clidir/ex.cli
# Clixon example specification
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
set @datamodel, cli_auto_set();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
discard("Discard edits (rollback 0)"), discard_changes();

show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "text", true, false);{
            cli("Show configuration as CLI commands"), cli_show_auto_mode("candidate", "cli", true, false, "report-all", "set ");
            xml("Show configuration as XML"), cli_show_auto_mode("candidate", "xml", true, false, NULL);
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
    sudo pkill -f clixon_backend # to be sure
    
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "Default value expected: interval=30"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/tr:transfer\" xmlns:tr=\"urn:example:transfer\"/><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><transfer xmlns=\"urn:example:transfer\"><interval>30</interval></transfer></data></rpc-reply>"

new "Set transfer/daily"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><transfer xmlns=\"urn:example:transfer\"><daily/></transfer></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Default value expected: time-of-day=01:00"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/tr:transfer\" xmlns:tr=\"urn:example:transfer\"/><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><transfer xmlns=\"urn:example:transfer\"><daily/><time-of-day>01.00</time-of-day></transfer></data></rpc-reply>"

new "Set list element transfer container"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><li xmlns=\"urn:example:transfer\"><x>42</x></li></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Default value expected: interval=30"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/tr:li\" xmlns:tr=\"urn:example:transfer\"/><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><li xmlns=\"urn:example:transfer\"><x>42</x><transfer><interval>30</interval></transfer></li></data></rpc-reply>"

new "Set transfer/daily"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><li xmlns=\"urn:example:transfer\"><x>42</x><transfer xmlns=\"urn:example:transfer\"><daily/></transfer></li></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Default value expected: time-of-day=01:00"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/tr:li\" xmlns:tr=\"urn:example:transfer\"/><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><li xmlns=\"urn:example:transfer\"><x>42</x><transfer><daily/><time-of-day>01.00</time-of-day></transfer></li></data></rpc-reply>"

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
