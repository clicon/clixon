#!/usr/bin/env bash
# Completion must resolve unprefixed typedefs in the grouping's defining module.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

cfg=$dir/conf_yang.xml

cat <<EOF1 > $dir/example-defs.yang
module example-defs {
    yang-version 1.1;
    namespace "urn:example:defs";
    prefix defs;

    typedef my-key-type {
        type string {
            length "1..64";
        }
    }

    grouping cfg-top {
        list item {
            key name;
            leaf name {
                type my-key-type;
            }
            leaf value {
                type string;
            }
        }
    }
}
EOF1

cat <<EOF1 > $dir/example.yang
module example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;

    import example-defs { prefix defs; }

    container top {
        uses defs:cfg-top;
    }
}
EOF1

AUTOCLI=$(autocli_config 'example*' kw-nokey false)
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

new "test params: -s init -f $cfg"
if [ $BE -ne 0 ]; then
    new "start backend"
    start_backend -s init -f $cfg
fi
new "wait backend"
wait_backend

new "config-path-info resolves an unprefixed typedef in the defining module"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><config-path-info $LIBNS><xpath>/ex:top/ex:item/ex:name</xpath><leafref-refer>true</leafref-refer></config-path-info></rpc>" '<symbol xmlns="http://clicon.org/lib">name</symbol>' "" --not-- 'No such type'

new "populate a list defined in a cross-module grouping"
expectpart "$($clixon_cli -1 -f $cfg set top item foo value bar 2>&1)" 0 '^$'

new "completion resolves an unprefixed typedef in the defining module"
expectpart "$(printf 'set top item ?\025quit\n' | $clixon_cli -f $cfg 2>&1)" 0 'foo' --not-- 'No such type' 'Netconf error' 'Syntax error'

if [ $BE -ne 0 ]; then
    new "kill backend"
    stop_backend -f $cfg
fi
rm -rf $dir
new "endtest"
endtest
