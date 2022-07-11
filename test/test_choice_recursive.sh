#!/usr/bin/env bash
# Test hierarchical choices
# See eg https://github.com/clicon/clixon/issues/342

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/choice.xml
clidir=$dir/cli
fyang=$dir/type.yang

test -d ${clidir} || rm -rf ${clidir}
mkdir $clidir

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module system{
  yang-version 1.1;
  namespace "urn:example:config";
  prefix ex;
    container c {
	choice top{
	    case topA {
		choice A{
		    leaf A1x{
			type string;
		    }
		    leaf A2x{
			type string;
		    }
		}
		leaf Ay{
		    type string;
		}
	    }
	    case topB{
		choice B{
		    case B1{
			leaf B1x{
			    type string;
			}
		    }
		    case B2{
			leaf B2x{
			    type string;
			}
		    }
		}
		leaf By{
		    type string;
		}
	    }
	}
    }
}
EOF

cat <<EOF > $clidir/ex.cli
# Clixon example specification
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
set @datamodel, cli_auto_set();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
discard("Discard edits (rollback 0)"), discard_changes();

show("Show a particular state of the system"){
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "xml", false, false);
}
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure
    
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "cli set 2nd A stmt"
expectpart "$($clixon_cli -1 -f $cfg -l o set c Ay foo)" 0 "^$"

new "show config"
expectpart "$($clixon_cli -1 -f $cfg -l o show config)" 0 "^<c xmlns=\"urn:example:config\"><Ay>foo</Ay></c>$"

new "cli set 1st B stmt"
expectpart "$($clixon_cli -1 -f $cfg -l o set c B1x bar)" 0 "^$"

new "show config, Ay removed"
expectpart "$($clixon_cli -1 -f $cfg -l o show config)" 0 "^<c xmlns=\"urn:example:config\"><B1x>bar</B1x></c>$" --not-- "<Ay>foo</Ay>"

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
