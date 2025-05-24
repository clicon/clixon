#!/usr/bin/env bash
# Delete and remove of choice with leafs of type strings and empty

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/choice.xml
clidir=$dir/cli
fyang=$dir/$APPNAME.yang

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
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example{
  yang-version 1.1;
  namespace "urn:example:config";
  prefix ex;
  container system{
    container strings {
       choice name {
         case a {
           leaf x {
             type string;
           }
         }
         case b {
           leaf y {
             type string;
           }
         }
       }
    }
    container empty {
       choice name {
         case a {
           leaf x {
             type empty;
           }
         }
         case b {
           leaf y {
             type string;
           }
         }
       }
    }
    container empty2 {
       choice name {
         case a {
           leaf x {
             type string;
           }
         }
         case b {
           leaf y {
             type empty;
           }
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
      @datamodel, @add:leafref-no-refer, cli_auto_del();
      all("Delete whole candidate configuration"), delete_all("candidate");
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
discard("Discard edits (rollback 0)"), discard_changes();

show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", true, false);
}
EOF


# Set value in one choice
# Args:
# 1:   config to set
function testset()
{
    conf=$1

    new "netconf set ${conf}"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:config\">${conf}</system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
}

# Delete value in other choice
# Args:
# 1:  Operation: delete or remove
# 2:  Configured data
# 3:  Container to construct delete/remove xml
# 4:  errmsg
function testdel()
{
    op=$1
    conf=$2
    container=$3
    empty=$4
    errmsg=$5

    if ($errmsg); then
        reply="<error-message>Data does not exist; cannot delete resource</error-message>"
    else
        reply="<ok/>"
    fi
    
    opstring="<${container}><y nc:operation=\"${op}\">42</y></${container}>"
    new "netconf ${opstring} 1"

    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><edit-config><target><candidate/></target><default-operation>none</default-operation><config><system xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">${opstring}</system></config></edit-config></rpc>" "$reply" ""

    new "Check still there 1"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><get-config><source><candidate/></source></get-config></rpc>" "${conf}" ""

    opstring="<${container}><x nc:operation=\"${op}\">79</x></${container}>"
    new "netconf ${opstring} 2"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><edit-config><target><candidate/></target><default-operation>none</default-operation><config><system xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">${opstring}</system></config></edit-config></rpc>" "$reply"

    new "Check still there 2"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><get-config><source><candidate/></source></get-config></rpc>" "${conf}" ""
    
    #    if ! ${empty}; then
    if false; then
        opstring="<${container}><x nc:operation=\"${op}\"/></${container}>"
        new "netconf ${opstring} 3"
        echo "<system xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">${opstring}</system>"
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><edit-config><target><candidate/></target><default-operation>none</default-operation><config><system xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">${opstring}</system></config></edit-config></rpc>]]>]]>" "$reply" ""

        new "Check removed 4"
        expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><get-config><source><candidate/></source></get-config></rpc>" "<data/>" ""

        testset $conf
        
    fi
    
    if $empty; then
        opstring="<${container}><x nc:operation=\"${op}\"/></${container}>"
    else
        opstring="<${container}><x nc:operation=\"${op}\">42</x></${container}>"
    fi
    new "netconf ${opstring} 4"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><edit-config><target><candidate/></target><default-operation>none</default-operation><config><system xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">${opstring}</system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "Check removed 4"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><get-config><source><candidate/></source></get-config></rpc>" "<data/>" ""
}

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

new "set string case, remove w string"
conf="<strings><x>42</x></strings>"

testset "$conf"
testdel remove "${conf}" "strings" false false

testset "${conf}"
testdel delete "${conf}" "strings" false true

new "set empty case, remove w string"

conf="<empty><x/></empty>"

testset "${conf}"
testdel remove "${conf}" "empty" true false

testset "${conf}"
testdel delete "${conf}" "empty" true true

new "set string case, remove w empty"
conf="<empty2><x/></empty2>"

testset "${conf}"
testdel remove "${conf}" "empty2" true false

testset "${conf}"
testdel delete "${conf}" "empty2" true true

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
