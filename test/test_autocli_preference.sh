#!/usr/bin/env bash
# Test of autocli string pattern ambiguity in unions
# A union with more than one string pattern can be "ambiguous" but resolves with preference
# setting of first element.
# Also test with explicit non-auto cli commands

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
clispec=$dir/automode.cli
fyang=$dir/clixon-example.yang

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    import ietf-inet-types {
        prefix inet;
    }
    leaf value1 {
        description "Single layer union";
        type union {
            type string{
                pattern "[a-z]+";
            }
            type string{
                pattern "[b-z0-9]+";
            }
        }
    }
    leaf value2 {
        description "Two layer union";
        type union {
            type union {
              type string{
                  pattern "[a-z]+";
              }
            }
            type string{
                pattern "[b-z0-9]+";
            }
        }
    }
    leaf inet-host {
        description "more complicated type structure";
        type inet:host;
    }
}
EOF

cat <<EOF > $clispec
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

onetwo {
    # bcd is proper ambiguous
    <a:string regexp:"[a-z]+">, mycallback("one");
    <b:string regexp:"[b-z0-9]+">, mycallback("two");
}
three {
    # bcd should not be ambiguous
    (<a:string regexp:"[a-z]+" preference:9>|<b:string regexp:"[b-z0-9]+">), mycallback("three");
}
# Autocli syntax tree operations
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") @datamodel, @add:leafref-no-refer, cli_auto_del();
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "text", true, false);{
            xml("Show configuration as XML"), cli_show_auto_mode("candidate", "xml", false, false);
            cli("Show configuration as CLI commands"), cli_show_auto_mode("candidate", "cli", false, false, "report-all", "set ");
            netconf("Show configuration as netconf edit-config operation"), cli_show_auto_mode("candidate", "netconf", false, false);
            text("Show configuration as text"), cli_show_auto_mode("candidate", "text", false, false);
            json("Show configuration as JSON"), cli_show_auto_mode("candidate", "json", false, false);
    }
    state("Show configuration and state"), cli_show_auto_mode("running", "xml", false, true);
}
EOF

# Use yang in example
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  ${AUTOCLI}
</clixon-config>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

new "autocli value2"
expectpart "$($clixon_cli -1 -f $cfg set value2 bcd)" 0 "^$"

new "autocli inet-host"
expectpart "$($clixon_cli -1 -f $cfg set inet-host 10.10.10.10)" 0 "^$"

new "autocli match first"
expectpart "$($clixon_cli -1 -f $cfg set value1 abc)" 0 "^$"

new "autocli match second"
expectpart "$($clixon_cli -1 -f $cfg set value1 bc9)" 0 "^$"

new "autocli match third"
expectpart "$($clixon_cli -1 -f $cfg set value1 bcd)" 0 "^$"

new "cli match first"
expectpart "$($clixon_cli -1 -f $cfg onetwo abc 2>&1)" 0 "arg = one"

new "cli match second"
expectpart "$($clixon_cli -1 -f $cfg onetwo bc9 2>&1)" 0 "arg = two"

new "cli match both ambiguous"
expectpart "$($clixon_cli -1 -f $cfg onetwo bcd 2>&1)" 255 "is ambiguous"

new "cli match third one"
expectpart "$($clixon_cli -1 -f $cfg three abc 2>&1)" 0 "arg = three"

new "cli match third second"
expectpart "$($clixon_cli -1 -f $cfg three bc9 2>&1)" 0 "arg = three"

new "cli match third both"
expectpart "$($clixon_cli -1 -f $cfg three bcd 2>&1)" 0 "arg = three"

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
