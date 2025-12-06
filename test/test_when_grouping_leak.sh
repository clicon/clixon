#!/usr/bin/env bash
# When on a uses must stay local to that copy (issue #635). Guarded uses of a
# shared grouping must not leak their when condition to other modules using the
# same grouping without a when.

# Magic line must be first in script (see README.md)
s="$_"
. ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fplatform=$dir/test-platform.yang
fbase=$dir/test-base.yang
fguarded=$dir/test-guarded.yang
fopen=$dir/test-open.yang

cat <<EOF >$cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fplatform</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<'EOF' >$fbase
module test-base {
  yang-version 1.1;
  namespace "urn:test:base";
  prefix b;

  grouping shared {
    container payload {
      leaf value {
        type string;
      }
    }
  }
}
EOF

cat <<'EOF' >$fguarded
module test-guarded {
  yang-version 1.1;
  namespace "urn:test:guarded";
  prefix g;

  import test-base { prefix b; }

  container guarded {
    leaf enable {
      type boolean;
      default "false";
    }
    uses b:shared {
      when "enable = 'true'";
    }
  }
}
EOF

cat <<'EOF' >$fopen
module test-open {
  yang-version 1.1;
  namespace "urn:test:open";
  prefix o;

  import test-base { prefix b; }

  container open {
    uses b:shared;
  }
}
EOF

cat <<'EOF' >$fplatform
module test-platform {
  yang-version 1.1;
  namespace "urn:test:platform";
  prefix tp;

  import test-base { prefix b; }
  import test-guarded { prefix g; }
  import test-open { prefix o; }
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

OPENXML=$(
  cat <<EOF
<open xmlns="urn:test:open">
  <payload>
    <value>ok</value>
  </payload>
</open>
EOF
)

GUARDED_FALSE=$(
  cat <<EOF
<guarded xmlns="urn:test:guarded">
  <enable>false</enable>
  <payload>
    <value>blocked</value>
  </payload>
</guarded>
EOF
)

GUARDED_TRUE=$(
  cat <<EOF
<guarded xmlns="urn:test:guarded">
  <enable>true</enable>
  <payload>
    <value>allowed</value>
  </payload>
</guarded>
EOF
)

new "open container without when guard validates (no leakage from guarded uses)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$OPENXML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "guarded when=false should be rejected on edit-config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$GUARDED_FALSE</config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag>" ""

new "discard guarded failure"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "guarded enable=true with payload should validate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$GUARDED_TRUE</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "discard final"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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
