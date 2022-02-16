#!/usr/bin/env bash
# test of unions in autocli for leafs and keys
# See eg:
#  keys: https://github.com/clicon/clixon/issues/301
#  reftree: https://github.com/clicon/cligen/issues/73

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fspec=$dir/automode.cli
fyang=$dir/example.yang

cat <<EOF > $fyang
module example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    typedef uniontype {
        type union {
	    type enumeration {
                enum u1;
                enum u2;
            }
	    type string;
        }
    }
    /* Generic config data */
    container tableleaf{
	list parleaf{
	    description "leaf is union type";
	    key name;
	    leaf name{
		type string;
	    }
	    leaf value{
		type uniontype;
	    }
	}
    }
    container tablekey{
	list parkey{
	    description "key is union type";
	    key name;
	    leaf name{
		type uniontype;
	    }
	    leaf value{
		type string;
	    }
	}
    }
}
EOF

AUTOCLI=$(autocli_config example kw-nokey false)

# Use yang in example
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  ${AUTOCLI}
</clixon-config>
EOF

cat <<EOF > $fspec
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") @datamodel, cli_auto_del();
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
show("Show a particular state of the system")
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "text", true, false);
EOF

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

new "cli set leaf union"
expectpart "$($clixon_cli -1 -f $cfg set tableleaf parleaf a value u1)" 0 "^$"

new "cli set leaf union"
expectpart "$($clixon_cli -1 -f $cfg set tableleaf parleaf a value u1)" 0 "^$"
exit
new "cli query leaf union - basic"
expectpart "$(echo "set tableleaf parleaf a value ?" | $clixon_cli -f $cfg 2>/dev/null)" 0 u1 u2

new "cli query leaf union - count"
ret=$(echo "set tableleaf parleaf a value ?" | $clixon_cli -f $cfg 2>&1 2>/dev/null)
count=$(echo "$ret" | grep -c u1)
if [ $count -gt 1 ]; then
    err "number of u1: 1" $count
fi

new "cli set key union"
expectpart "$($clixon_cli -1 -f $cfg set tablekey parkey u1 value 42)" 0 "^$"

new "cli query key union - basic"
expectpart "$(echo "set tablekey parkey ?" | $clixon_cli -f $cfg 2>/dev/null)" 0 u1 u2

new "cli query leaf union - count"
ret=$(echo "set tablekey parkey ?" | $clixon_cli -f $cfg 2>&1 2>/dev/null)
count=$(echo "$ret" | grep -c u1)
if [ $count -gt 1 ]; then
    err "number of u1: 1" $count
fi

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

unset count
unset ret

new "endtest"
endtest
