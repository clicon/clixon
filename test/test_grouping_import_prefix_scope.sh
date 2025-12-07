#!/usr/bin/env bash
# Grouping in a submodule imports a module under one prefix, then the grouping is
# used from another module that imports the same module under a different prefix.
# Verify leafref resolution honors the lexical (submodule) prefix.

# Magic line must be first in script (see README.md)
s="$_"
. ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/grouping_import_prefix_scope.xml
fprov=$dir/prov-main.yang
fprovsub=$dir/prov-sub.yang
fcons=$dir/cons-main.yang
ftarget=$dir/if-target.yang

# Enable autocli for all loaded modules (cons-main, prov-main, if-target)
AUTOCLI=$(autocli_config "*" kw-nokey false)

cat <<EOF >$cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fcons</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  $AUTOCLI
</clixon-config>
EOF

cat <<'EOF' >$ftarget
module if-target {
  yang-version 1.1;
  namespace "urn:ift";
  prefix t;

  container interfaces {
    list interface {
      key "name";
      leaf name {
        type string;
      }
    }
  }
}
EOF

cat <<'EOF' >$fprov
module prov-main {
  yang-version 1.1;
  namespace "urn:prov";
  prefix p;

  include prov-sub;
}
EOF

cat <<'EOF' >$fprovsub
submodule prov-sub {
  belongs-to prov-main { prefix p; }
  yang-version 1.1;

  import if-target { prefix foo; }

  grouping g {
    container iface-ref {
      leaf iface {
        type leafref {
          path "/foo:interfaces/foo:interface/foo:name";
        }
      }
    }
  }
}
EOF

cat <<'EOF' >$fcons
module cons-main {
  yang-version 1.1;
  namespace "urn:cons";
  prefix c;

  import prov-main { prefix p; }
  import if-target { prefix bar; }

  container top {
    uses p:g;
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

XML=$(
  cat <<EOF
<interfaces xmlns="urn:ift">
  <interface>
    <name>eth0</name>
  </interface>
</interfaces>
<top xmlns="urn:cons">
  <iface-ref>
    <iface>eth0</iface>
  </iface-ref>
</top>
EOF
)

new "edit-config with grouping leafref defined in submodule import"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$XML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "validate candidate with grouping used across modules with different import prefixes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "cli add interface to serve as leafref target"
expectpart "$($clixon_cli -1 -f $cfg set interfaces interface eth0)" 0 "^$"

new "cli tab-complete leafref from grouping defined in submodule scope"
expectpart "$(printf 'set top iface-ref iface \t\n' | $clixon_cli -f $cfg 2>&1)" 0 eth0 --not-- "Prefix foo does not have an associated namespace" "Database error"

new "discard-changes"
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
