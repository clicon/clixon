#!/usr/bin/env bash
# transitive leafref->leafref leafref->identityref completion
# 

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
fyang=$dir/example-leafref.yang
clidir=$dir/clidir
if [ ! -d $clidir ]; then
    mkdir $clidir
fi
# Use yang in example

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example-leafref</CLICON_YANG_MODULE_MAIN>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example-leafref{
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;

    identity crypto-alg {
         description
           "Base identity from which all crypto algorithms
            are derived. (from: RFC7950 Sec 7.18 and 9.10)";
    }
    identity des {
         base "ex:crypto-alg";
         description "DES crypto algorithm.";
    }
    identity des2 {
         base "ex:crypto-alg";
         description "DES crypto algorithm.";
    }
    identity des3 {
         base "ex:crypto-alg";
         description "Triple DES crypto algorithm.";
    }
    /* Basic config data */
    container table{
	list parameter{
	    key name;
	    leaf name{
		type uint32;
	    }
	    leaf value{
		type string;
	    }
        }
    }
    /* first level leafref */
    container leafrefs {
        description "Leafref relative path, no require-instance";
	list leafref{
	   key name;
	   leaf name {
   	      type leafref{
                 path "../../../table/parameter/name";
		 require-instance false;
              }
           }
        }
    }
    /* first level leafref absolute */	
    container leafrefsabs {
        description "Leafref absolute path, no require-instance";
	list leafref{
	   key name;
	   leaf name {
   	      type leafref{
                 path "/table/parameter/name";
		 require-instance false;
              }
           }
        }
    }
    /* first level leafref require-instance */	
    container leafrefsreqinst {
        description "Leafref absolute path, require-instance true";
	list leafref{
	   key name;
	   leaf name {
   	      type leafref{
                 path "/table/parameter/name";
		 require-instance true;
              }
           }
        }
    }
    /* first level identityrefs */
    container identityrefs {
	list identityref{
	   description "Identityref base";
	   key name;
	   leaf name {
   	      type identityref{
	         base "ex:crypto-alg";
              }
           }
        }
    }
    /* second level leafref */
    container leafrefs2 {
	list leafref{
	   key name;
	   leaf name {
   	      type leafref{
                 path "../../../leafrefs/leafref/name";
		 require-instance false;
              }
           }
        }
    }
    /* second level identityref */
    container identityrefs2 {
	list identityref{
	   key name;
	   leaf name {
   	      type leafref{
                 path "../../../identityrefs/identityref/name";
		 require-instance false;
              }
           }
        }
    }
}
EOF

# clispec files 1..6 for submodes AAA and BBB as described in top comment

cat <<EOF > $clidir/cli1.cli
CLICON_MODE="example";
CLICON_PROMPT="cli> ";

# Autocli syntax tree operations
edit @datamodel, cli_auto_edit("datamodel");
up, cli_auto_up("datamodel");
top, cli_auto_top("datamodel");
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") {
      @datamodel, cli_auto_del(); 
      all("Delete whole candidate configuration"), delete_all("candidate");
}
show("Show a particular state of the system"){

    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "text", true, false);{
        cli("Show configuration as CLI commands"), cli_auto_show("datamodel", "candidate", "cli", true, false, "set ");
}
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
discard("Discard edits (rollback 0)"), discard_changes();
EOF

cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
   <table xmlns="urn:example:clixon">
      <parameter>
         <name>91</name>
      </parameter>
      <parameter>
         <name>92</name>
      </parameter>
      <parameter>
         <name>93</name>
      </parameter>
   </table>
</${DATASTORE_TOP}>
EOF

new "test params: -f $cfg -s startup"
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
    
new "expand identityref 1st level"
expectpart "$(echo "set identityrefs identityref ?" | $clixon_cli -f $cfg 2> /dev/null)" 0 "ex:des" "ex:des2" "ex:des3"

# XXX something wrong sometimes in this test on docker.
# Expected:
# <name>
# CLI syntax error: "set leafrefs leafref": Incomplete command
echo "set leafrefs leafref ?" | $clixon_cli -f $cfg -o CLICON_CLI_EXPAND_LEAFREF=false

new "expand leafref 1st level"
expectpart "$(echo "set leafrefs leafref ?" | $clixon_cli -f $cfg -o CLICON_CLI_EXPAND_LEAFREF=false 2> /dev/null)" 0 "<name>" --not-- "91" "92" "93"

new "expand leafref 1st level with leafref expand"
expectpart "$(echo "set leafrefs leafref ?" | $clixon_cli -f $cfg -o CLICON_CLI_EXPAND_LEAFREF=true 2> /dev/null)" 0 "91" "92" "93"

new "expand leafref top"
expectpart "$(echo "set leafrefsabs leafref ?" | $clixon_cli -f $cfg -o CLICON_CLI_EXPAND_LEAFREF=true 2> /dev/null)" 0 "91" "92" "93"

new "expand leafref require-instance"
expectpart "$(echo "set leafrefsreqinst leafref ?" | $clixon_cli -f $cfg -o CLICON_CLI_EXPAND_LEAFREF=true 2> /dev/null)" 0 "91" "92" "93"

# First level id/leaf refs
new "set identityref des"
expectpart "$($clixon_cli -1 -f $cfg set identityrefs identityref ex:des)" 0 "^$"

new "set identityref des3"
expectpart "$($clixon_cli -1 -f $cfg set identityrefs identityref ex:des3)" 0 "^$"

new "set leafref 91"
expectpart "$($clixon_cli -1 -f $cfg set leafrefs leafref 91)" 0 "^$"

new "set leafref 93"
expectpart "$($clixon_cli -1 -f $cfg set leafrefs leafref 93)" 0 "^"$

new "cli commit"
expectpart "$($clixon_cli -1 -f $cfg -l o commit)" 0 "^$"

new "set leafref str (expect failure)"
expectpart "$($clixon_cli -1 -l o -f $cfg set leafrefs leafref str)" 255 "'str' is not a number" 

# Make a netconf request to set wrong type to fail in validate
new "netconf set leafref str wrong type"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><leafrefs xmlns=\"urn:example:clixon\"><leafref><name>str</name></leafref></leafrefs></config><default-operation>merge</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "cli validate"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 255 "'str' is not a number <bad-element>name</bad-element>"

new "cli discard"
expectpart "$($clixon_cli -1 -f $cfg -l o discard)" 0 ""

new "set leafref 99 (non-existent)"
expectpart "$($clixon_cli -1 -f $cfg set leafrefs leafref 99)" 0 "^"$

new "cli commit"
expectpart "$($clixon_cli -1 -f $cfg -l o commit)" 0 "^$"

# require-instance
new "set leafref require-instance 99 (non-existent)"
expectpart "$($clixon_cli -1 -f $cfg set leafrefsreqinst leafref 99)" 0 "^"$

new "cli validate expect failure"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 255 "Leafref validation failed: No leaf 99 matching path"

new "cli discard"
expectpart "$($clixon_cli -1 -f $cfg -l o discard)" 0 ""

# Second level id/leaf refs
new "expand identityref 2nd level"
expectpart "$(echo "set identityrefs2 identityref ?" | $clixon_cli -f $cfg 2> /dev/null)" 0 "ex:des" "ex:des2" "ex:des3" 

# Note CI may have random number as host which may match "92"
new "expand leafref 2nd level"
expectpart "$(echo "set leafrefs2 leafref ?" | $clixon_cli -f $cfg -o CLICON_CLI_EXPAND_LEAFREF=true 2> /dev/null)" 0 " 91" " 93" --not-- " 92"

new "set identityref2 des"
expectpart "$($clixon_cli -1 -f $cfg set identityrefs2 identityref ex:des)" 0 "^$"

new "set leafref2 91"
expectpart "$($clixon_cli -1 -f $cfg set leafrefs2 leafref 91)" 0 "^$"

new "cli commit"
expectpart "$($clixon_cli -1 -f $cfg -l o commit)" 0 "^$"

new "show config"
expectpart "$($clixon_cli -1 -f $cfg -l o show config cli)" 0 "set table parameter 91" "set table parameter 92" "set table parameter 93" "set leafrefs leafref 91" "set leafrefs leafref 93" "set identityrefs identityref ex:des" "set identityrefs identityref ex:des3" "set leafrefs2 leafref 91" "set identityrefs2 identityref ex:des" --not-- "set identityrefs identityref ex:des2" "set leafrefs leafref 92"

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
