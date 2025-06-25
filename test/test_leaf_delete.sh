#!/usr/bin/env bash
# Remove leaf with:
# (1) <a operation=”remove”>x</a>
# (2) <a operation=”remove”/>
# See https://github.com/clicon/clixon-controller/issues/203
# Remove leaf-list with:
# (3) <a operation=”remove”>x</a>
# (4) <a operation=”remove”/>
# JunOS does not accept (1), and removes all with (4)
# Clixon removes the empty leaf with (4)

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
     container conf{
       leaf x {
         type string;
       }
       leaf y {
         type empty;
       }
       leaf-list z {
         type string;
       }
       list metric {
          key "name";
          leaf name {
             type string;
          }
          leaf value {
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

#
function testset()
{
    conf=$1

    new "netconf set"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>${conf}</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
}

#
function testdel()
{
    delop=$1
    new "netconf del"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><edit-config><target><candidate/></target><default-operation>none</default-operation><config><system xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\"><conf>${delop}</conf></system></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
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

conf="<system xmlns=\"urn:example:config\"><conf><x>1</x><y/><z/><z>2</z><z>3</z></conf></system>"

testset "$conf"

new "delete x"
testdel "<x nc:operation=\"delete\"/>"

new "Check deleted"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><get-config><source><candidate/></source></get-config></rpc>" "<conf><y/><z/><z>2</z><z>3</z></conf>" ""

testset "$conf"

new "delete x=1"
testdel "<x nc:operation=\"delete\">1</x>"

new "Check deleted"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><get-config><source><candidate/></source></get-config></rpc>" "<conf><y/><z/><z>2</z><z>3</z></conf>" ""

testset "$conf"

new "delete y"
testdel "<y nc:operation=\"delete\"/>"

new "Check deleted"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><get-config><source><candidate/></source></get-config></rpc>" "<conf><x>1</x><z/><z>2</z><z>3</z></conf>" ""

testset "$conf"

new "delete z=2"
testdel "<z nc:operation=\"delete\">2</z>"

new "Check deleted"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><get-config><source><candidate/></source></get-config></rpc>" "<conf><x>1</x><y/><z/><z>3</z></conf>" ""

testset "$conf"

new "delete z"
testdel "<z nc:operation=\"delete\"/>"

new "Check deleted"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><get-config><source><candidate/></source></get-config></rpc>" "<conf><x>1</x><y/><z>2</z><z>3</z></conf>" ""

# https://github.com/clicon/clixon/issues/611
conf="<system xmlns=\"urn:example:config\"><conf><metric><name>m1</name></metric></conf></system>"
new "Unexpected entry at remove"
testset "$conf"

testdel "<metric><name>m2</name><value nc:operation=\"remove\"/></metric>"

new "Check deleted"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><get-config><source><candidate/></source></get-config></rpc>" "<conf><metric><name>m1</name></metric></conf>" ""

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
