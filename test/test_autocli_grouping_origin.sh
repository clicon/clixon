#!/usr/bin/env bash
# Regression test for grouping resolution via original statement context.
# Covers nested uses in a submodule grouping consumed from another module.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_grouping_origin.xml
fprov=$dir/prov-main.yang
fprovsub=$dir/prov-sub.yang
fcons=$dir/cons-main.yang

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

cat <<'EOF' >$fprov
module prov-main {
  yang-version 1.1;
  namespace "urn:test:prov-main";
  prefix pm;

  include prov-sub;
}
EOF

cat <<'EOF' >$fprovsub
submodule prov-sub {
  yang-version 1.1;
  belongs-to prov-main { prefix pm; }

  grouping inner {
    leaf v {
      type string;
    }
  }

  grouping wrapper {
    container wrapped {
      uses inner;
    }
  }
}
EOF

cat <<'EOF' >$fcons
module cons-main {
  yang-version 1.1;
  namespace "urn:test:cons-main";
  prefix cm;

  import prov-main { prefix pm; }

  container top {
    uses pm:wrapper;
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

new "autocli generation should not report unresolved grouping"
expectpart "$($clixon_cli -f $cfg -G -1 2>&1)" 0 --not-- "grouping " " not found in " "Database error"

new "set leaf under nested grouping uses"
expectpart "$($clixon_cli -f $cfg -1 set top wrapped v hello)" 0 "^$"

new "validate candidate"
expectpart "$($clixon_cli -f $cfg -1 validate)" 0 "^$"

new "commit candidate"
expectpart "$($clixon_cli -f $cfg -1 commit)" 0 "^$"

new "show config contains nested grouping value"
expectpart "$($clixon_cli -f $cfg -1 show config)" 0 \
  "<top xmlns=\"urn:test:cons-main\">" \
  "<wrapped>" \
  "<v>hello</v>" \
  "</wrapped>" \
  "</top>"

new "discard-changes"
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
