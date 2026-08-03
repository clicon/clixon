#!/usr/bin/env bash
# Test for issue #678: two augments adding same-named containers (different namespaces)
# at the same schema level must sort deterministically.
#
# Without the fix in xml_cmp (stable pointer tiebreaker for y1!=y2, yi1==yi2),
# the two containers could sort in different orders on successive xml_sort calls,
# causing spurious diffs and transaction flip-flops that produce duplicate list entries.
#
# Scenario:
#  - module base: container ntp { container auth {...}; list uc { key "addr"; } }
#  - module ext1: augment /base:ntp { container auth { leaf x ... } }
#  - module ext2: augment /base:ntp { container auth { leaf y ... } }
#  => base:auth and ext1:auth and ext2:auth coexist at the same level.
#     Their yang_order() values tie (same schema position), so sort must be stable.
#
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fbase=$dir/base.yang
fext1=$dir/ext1.yang
fext2=$dir/ext2.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# Base module: container ntp with a list and a base auth container
cat <<EOF > $fbase
module base {
  yang-version 1.1;
  namespace "urn:example:base";
  prefix base;

  container ntp {
    container auth {
      description "Base auth container";
      leaf enabled {
        type boolean;
        default false;
      }
    }
    list uc {
      description "Unicast configuration list (mirrors ietf-ntp pattern)";
      key addr;
      leaf addr {
        type string;
      }
      leaf prefer {
        type boolean;
        default false;
      }
      leaf port {
        type uint16;
        default 123;
      }
    }
  }
}
EOF

# ext1 augments /ntp with its own auth container (different namespace)
cat <<EOF > $fext1
module ext1 {
  yang-version 1.1;
  namespace "urn:example:ext1";
  prefix ext1;
  import base { prefix base; }

  augment "/base:ntp" {
    container auth {
      description "ext1 auth container (same local name, different namespace)";
      leaf key-id {
        type uint32;
      }
    }
  }
}
EOF

# ext2 augments /ntp with yet another auth container (different namespace)
cat <<EOF > $fext2
module ext2 {
  yang-version 1.1;
  namespace "urn:example:ext2";
  prefix ext2;
  import base { prefix base; }

  augment "/base:ntp" {
    container auth {
      description "ext2 auth container (same local name, different namespace)";
      leaf algo {
        type string;
      }
    }
  }
}
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

# Set all three auth containers + a list entry + an extra leaf to delete later
new "netconf set base:auth, ext1:auth, ext2:auth and list entry"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>
      <ntp xmlns=\"urn:example:base\">
        <auth>
          <enabled>true</enabled>
        </auth>
        <auth xmlns=\"urn:example:ext1\">
          <key-id>42</key-id>
        </auth>
        <auth xmlns=\"urn:example:ext2\">
          <algo>md5</algo>
        </auth>
        <uc>
          <addr>10.0.0.1</addr>
          <prefer>true</prefer>
          <port>123</port>
        </uc>
      </ntp>
    </config></edit-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Make an unrelated change: delete the prefer leaf from the list entry.
# If xml_sort is non-deterministic on the auth containers, this unrelated
# edit will trigger spurious diffs on the auth containers.
new "netconf unrelated change: delete prefer leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
       <default-operation>none</default-operation>
       <config>
         <ntp xmlns=\"urn:example:base\">
           <uc>
             <addr>10.0.0.1</addr>
             <prefer xmlns:nc=\"${BASENS}\" nc:operation=\"delete\"/>
           </uc>
         </ntp>
       </config>
     </edit-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Validate: must succeed with no errors about auth containers
new "netconf validate no spurious diff (issue #678)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit unrelated change"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Verify list entry exists exactly once (no duplicate due to spurious diff)
new "netconf get-config: uc entry exists exactly once (no duplicate)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/base:ntp/base:uc\" xmlns:base=\"urn:example:base\"/></get-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><data><ntp xmlns=\"urn:example:base\"><uc><addr>10.0.0.1</addr><port>123</port></uc></ntp></data></rpc-reply>"

# Verify all three auth containers are still present with correct content
new "netconf get-config: base:auth still intact"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/base:ntp/base:auth\" xmlns:base=\"urn:example:base\"/></get-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><data><ntp xmlns=\"urn:example:base\"><auth><enabled>true</enabled></auth></ntp></data></rpc-reply>"

new "netconf get-config: ext1:auth still intact"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/base:ntp/ext1:auth\" xmlns:base=\"urn:example:base\" xmlns:ext1=\"urn:example:ext1\"/></get-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><data><ntp xmlns=\"urn:example:base\"><auth xmlns=\"urn:example:ext1\"><key-id>42</key-id></auth></ntp></data></rpc-reply>"

new "netconf get-config: ext2:auth still intact"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/base:ntp/ext2:auth\" xmlns:base=\"urn:example:base\" xmlns:ext2=\"urn:example:ext2\"/></get-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><data><ntp xmlns=\"urn:example:base\"><auth xmlns=\"urn:example:ext2\"><algo>md5</algo></auth></ntp></data></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><discard-changes/></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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
