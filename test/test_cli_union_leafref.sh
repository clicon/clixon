#!/usr/bin/env bash
# Union leafref keys must preserve child commands and the typedef's prefix scope.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example
cfg=$dir/conf_yang.xml

cat <<EOF1 > $dir/example-targets.yang
module example-targets {
    yang-version 1.1;
    namespace "urn:example:targets";
    prefix t;
    list port {
        key name;
        leaf name { type string; }
    }
    list lag {
        key name;
        leaf name { type string; }
    }
    typedef port-ref {
        type leafref { path "/t:port/t:name"; }
    }
    typedef relative-ref {
        type leafref { path "../name"; }
    }
    typedef endpoint-ref {
        type union {
            type port-ref;
            type leafref { path "/t:lag/t:name"; }
        }
    }
}
EOF1

cat <<EOF1 > $dir/example.yang
module example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    // The defining module's prefix t is deliberately unavailable here.
    import example-targets { prefix target; }
    leaf primary { type target:port-ref; }
    list endpoint {
        key name;
        leaf name { type target:endpoint-ref; }
        leaf cost { type uint32; }
        leaf alias { type target:relative-ref; }
    }
}
EOF1

AUTOCLI=$(autocli_config 'example*' kw-nokey false | sed 's|<autocli>|<autocli><completion-default>true</completion-default>|')
cat <<EOF1 > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLI_MODE>example</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>$dir/backend.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/backend.pid</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  ${AUTOCLI}
</clixon-config>
EOF1

cat <<EOF1 > $dir/example.cli
CLICON_MODE="example";
set @datamodel, cli_auto_set();
validate, cli_validate();
show, cli_show_auto_mode("candidate", "xml", false, false);
quit, cli_quit();
EOF1

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "start backend"
    start_backend -s init -f $cfg
fi
new "wait backend"
wait_backend

new "populate both leafref targets"
expectpart "$($clixon_cli -1 -f $cfg set port p1 2>&1)" 0 '^$'
expectpart "$($clixon_cli -1 -f $cfg set lag lag1 2>&1)" 0 '^$'

new "completion of imported union leafref typedef"
expectpart "$(printf 'set endpoint ?\025quit\n' | $clixon_cli -f $cfg 2>&1)" 0 'p1' 'lag1' --not-- 'Netconf error' 'Syntax error'

new "completion of imported ordinary leafref typedef"
expectpart "$(printf 'set primary ?\025quit\n' | $clixon_cli -f $cfg 2>&1)" 0 'p1' --not-- 'Netconf error' 'Syntax error'

for completion in false true; do
    new "union keys retain child commands with completion=$completion"
    sed -i "s|<completion-default>.*</completion-default>|<completion-default>$completion</completion-default>|" $cfg
    expectpart "$($clixon_cli -1 -f $cfg set endpoint p1 cost 10 2>&1)" 0 '^$'
    expectpart "$($clixon_cli -1 -f $cfg set endpoint lag1 cost 20 2>&1)" 0 '^$'
    expectpart "$($clixon_cli -1 -f $cfg show 2>&1)" 0 '<name>p1</name><cost>10</cost>' '<name>lag1</name><cost>20</cost>'
done

new "unprefixed typedef paths use the consuming node namespace"
expectpart "$(printf 'set endpoint p1 alias ?\025quit\n' | $clixon_cli -f $cfg 2>&1)" 0 '  p1' --not-- 'Netconf error' 'Syntax error'

new "union leafrefs validate against existing targets"
expectpart "$($clixon_cli -1 -f $cfg validate 2>&1)" 0 '^$'
expectpart "$($clixon_cli -1 -f $cfg set endpoint absent cost 30 2>&1)" 0 '^$'
expectpart "$($clixon_cli -1 -f $cfg validate 2>&1)" 255 'instance-required'

if [ $BE -ne 0 ]; then
    new "kill backend"
    stop_backend -f $cfg
fi
rm -rf $dir
new "endtest"
endtest
