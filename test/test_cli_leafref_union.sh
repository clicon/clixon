#!/usr/bin/env bash
# Autocli: leaf with a union of several leafrefs
#  - completion lists the values of all the referred lists
#  - the leaf has a single token value (not a "rest" variable accepting endless input)

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fyang=$dir/example-leafref-union.yang
clidir=$dir/clidir
if [ ! -d $clidir ]; then
    mkdir $clidir
fi

AUTOCLI=$(autocli_config example-leafref-union kw-nokey false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  $AUTOCLI
</clixon-config>
EOF

cat <<EOF > $fyang
module example-leafref-union{
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    container lists {
        list standard{
            key name;
            leaf name{
                type string;
            }
        }
        list expanded{
            key name;
            leaf name{
                type string;
            }
        }
    }
    container refs {
        list ref{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type union {
                    type leafref {
                        path "../../../lists/standard/name";
                    }
                    type leafref {
                        path "../../../lists/expanded/name";
                    }
                }
            }
        }
    }
}
EOF

cat <<EOF > $clidir/cli1.cli
CLICON_MODE="example";
CLICON_PROMPT="cli> ";

set @datamodel, cli_auto_set();
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "cli", true, false, "report-all", "set ");
}
EOF

new "test params: -f $cfg -s init"
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

# One cli session: all commands operate on the same candidate
new "expand union of leafrefs: values of both referred lists"
expectpart "$(echo "set lists standard std1
set lists expanded exp1
set refs ref a value ?" | $clixon_cli -f $cfg 2> /dev/null)" 0 "std1" "exp1"

new "set values of both leafrefs"
expectpart "$(echo "set lists standard std1
set lists expanded exp1
set refs ref a value std1
set refs ref b value exp1
show configuration" | $clixon_cli -f $cfg -l o 2> /dev/null)" 0 "set refs ref a value std1" "set refs ref b value exp1"

new "a second value is not accepted (single token, not rest)"
expectpart "$(echo "set lists standard std1
set lists expanded exp1
set refs ref c value std1 exp1
show configuration" | $clixon_cli -f $cfg -l o 2> /dev/null)" 0 "nknown command" --not-- '"std1 exp1"'

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
