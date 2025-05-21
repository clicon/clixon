#!/usr/bin/env bash
# Test of autocli for yang status value:
# - depreceted - hidden
# - obsolete - skipped

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

echo "AUTOCLI:$AUTOCLI"

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
clispec=$dir/automode.cli
fyang=$dir/clixon-example.yang

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    /* Generic config data */
    container table{
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
        }
    }
    container container-obsolete{
        status obsolete;
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
        }
    }
    container list-obsolete{
        list parameter{
            key name;
            status obsolete;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
        }
    }
    container leaf-obsolete{
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                status obsolete;
                type string;
            }
        }
    }
    container container-deprecated{
        status deprecated;
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
        }
    }
    container list-deprecated{
        list parameter{
            key name;
            status deprecated;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
        }
    }
    container leaf-deprecated{
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                status deprecated;
                type string;
            }
        }
    }

}
EOF

cat <<EOF > $clispec
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

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

new "set table expected ok"
expectpart "$($clixon_cli -1 -f $cfg set table parameter x value 42)" 0 "^$"

new "check completion on query"
expectpart "$(echo "set ?" | $clixon_cli -f $cfg 2>&1)" 0 "table" "list-obsolete" "list-deprecated" "leaf-obsolete" "leaf-deprecated" --not-- "container-obsolete" "container-deprecated"

new "set container obsolete expected fail"
expectpart "$($clixon_cli -1 -f $cfg set container-obsolete 2>&1)" 255 "CLI syntax error"

new "set list obsolete expected ok"
expectpart "$($clixon_cli -1 -f $cfg set list-obsolete 2>&1)" 0 "^$"

new "set list obsolete expected fail"
expectpart "$($clixon_cli -1 -f $cfg set list-obsolete parameter x 2>&1)" 255 "CLI syntax error"

new "set leaf obsolete expected ok"
expectpart "$($clixon_cli -1 -f $cfg set leaf-obsolete parameter x 2>&1)" 0 "^$"

new "set leaf obsolete expected fail"
expectpart "$($clixon_cli -1 -f $cfg set leaf-obsolete parameter x value 42 2>&1)" 255 "CLI syntax error"

# deprecated
new "set container deprecated expected fail"
expectpart "$($clixon_cli -1 -f $cfg set container-deprecated parameter x value 33 2>&1)" 0 "^$"

new "check container depreatced ?"
expectpart "$(echo "set container-deprecated ? " | $clixon_cli -f $cfg 2>&1)" 0 --not-- "parameter"

new "set list deprecated expected ok"
expectpart "$($clixon_cli -1 -f $cfg set list-deprecated parameter x value 32 2>&1)" 0 "^$" 

new "check list deprecated ?"
expectpart "$(echo "set list-deprecated ? " | $clixon_cli -f $cfg 2>&1)" 0 --not-- "parameter"

new "set leaf deprecated expected ok"
expectpart "$($clixon_cli -1 -f $cfg set leaf-deprecated parameter x value 44 2>&1)" 0 "^$"

new "check leaf deprecated ?"
expectpart "$(echo "set leaf-deprecated ? " | $clixon_cli -f $cfg 2>&1)" 0 "parameter"

new "check leaf deprecated ?"
expectpart "$(echo "set leaf-deprecated parameter x ? " | $clixon_cli -f $cfg 2>&1)" 0 --not-- value


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
