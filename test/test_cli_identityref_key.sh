#!/usr/bin/env bash
# CLI tests for identityref list key bugs (issue #662)
#
# Three related bugs when an identityref is part of a composite list key:
#  1. Spurious <type> free-text placeholder shown alongside enumerated identities
#  3a. Unprefixed form accepted, allowing duplicate list entries
#
# The YANG models the ietf-ntp unicast-configuration pattern:
#   list uc { key "address type"; leaf type { type identityref { base uc-type; } } }

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/$APPNAME.yang

AUTOCLI=$(autocli_config ${APPNAME} kw-all false)

cat <<XMLEOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  ${AUTOCLI}
</clixon-config>
XMLEOF

# YANG with composite key where the second key leaf is identityref.
# Mirrors the ietf-ntp unicast-configuration pattern from issue #662.
cat <<YANGEOF > $fyang
module $APPNAME {
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;

  identity uc-type {
    description "Base identity for unicast configuration type";
  }
  identity uc-server {
    base ex:uc-type;
  }
  identity uc-peer {
    base ex:uc-type;
  }

  container ntp {
    list uc {
      description "List with composite key: address + identityref type (issue #662)";
      key "address type";
      leaf address {
        type string;
      }
      leaf type {
        type identityref {
          base ex:uc-type;
        }
      }
      leaf maxpoll {
        type uint8;
        default 10;
      }
    }
  }
}
YANGEOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

# ---- Bug 1: completion should show ONLY prefixed identities, NOT a free-text <type> ----

new "completion: identityref key type shows prefixed identities ex:uc-server and ex:uc-peer not free-text <type> placeholder"
expectpart "$(echo "set ntp uc address 192.168.0.1 type ?" | $clixon_cli -f $cfg 2>&1)" 0 "ex:uc-server" "ex:uc-peer" --not-- "<type>"

# ---- Bug 3a: unprefixed form must NOT be accepted as a key value ----

new "cli set prefixed identityref key (ex:uc-server) should succeed"
expectpart "$($clixon_cli -1 -f $cfg -l o set ntp uc address 192.168.0.1 type ex:uc-server)" 0 "^$"

new "cli validate after prefixed key set"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 0 "^$"

new "cli discard"
expectpart "$($clixon_cli -1 -f $cfg -l o discard)" 0 "^$"

new "cli set unprefixed identityref key (uc-server) must be rejected (bug 3a)"
expectpart "$($clixon_cli -1 -f $cfg -l o set ntp uc address 192.168.0.1 type uc-server)" 255 ""

# ---- prefixed key followed by further leaf args (bug 2 regression guard) ----

new "cli set prefixed key with additional leaf (maxpoll) on same line"
expectpart "$($clixon_cli -1 -f $cfg -l o set ntp uc address 192.168.0.1 type ex:uc-server maxpoll 6)" 0 "^$"

new "cli validate after prefixed key + extra leaf"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 0 "^$"

new "cli discard"
expectpart "$($clixon_cli -1 -f $cfg -l o discard)" 0 "^$"

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

new "Endtest"
endtest

rm -rf $dir
