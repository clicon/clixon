#!/usr/bin/env bash
# When on a uses must stay local even inside a single module (issue #635).

# Magic line must be first in script (see README.md)
s="$_"
. ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang_single.xml
fcollapsed=$dir/test-collapsed.yang

cat <<EOF >$cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fcollapsed</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<'EOF' >$fcollapsed
module test-collapsed {
  yang-version 1.1;
  namespace "urn:test:collapsed";
  prefix tc;

  grouping shared {
    container payload {
      leaf value {
        type string;
      }
    }
  }

  container guarded {
    leaf enable {
      type boolean;
      default "false";
    }
    uses shared {
      when "enable = 'true'";
    }
  }

  container open {
    uses shared;
  }
}
EOF

new "test params (collapsed module): -f $cfg"

if [ $BE -ne 0 ]; then
  new "kill old backend (collapsed)"
  sudo clixon_backend -zf $cfg
  if [ $? -ne 0 ]; then
    err
  fi
  new "start backend -s init -f $cfg"
  start_backend -s init -f $cfg
fi

new "wait backend (collapsed)"
wait_backend

OPENXML=$(
  cat <<EOF
<open xmlns="urn:test:collapsed">
  <payload>
    <value>ok</value>
  </payload>
</open>
EOF
)

GUARDED_FALSE=$(
  cat <<EOF
<guarded xmlns="urn:test:collapsed">
  <enable>false</enable>
  <payload>
    <value>blocked</value>
  </payload>
</guarded>
EOF
)

GUARDED_TRUE=$(
  cat <<EOF
<guarded xmlns="urn:test:collapsed">
  <enable>true</enable>
  <payload>
    <value>allowed</value>
  </payload>
</guarded>
EOF
)

new "open container validates in single module (no leakage)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$OPENXML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "guarded when=false rejected in single module"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$GUARDED_FALSE</config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag>" ""

new "discard guarded failure (single)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "guarded enable=true with payload validates (single)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$GUARDED_TRUE</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "discard final (collapsed)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

if [ $BE -ne 0 ]; then
  new "Kill backend (collapsed)"
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
