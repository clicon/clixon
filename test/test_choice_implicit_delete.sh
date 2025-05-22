#!/usr/bin/env bash
# test of choice implicit delete, see RFC7950 Sec 7.9 3rd paragraph:
#   Since only one of the choice's cases can be valid at any time in the
#   data tree, the creation of a node from one case implicitly deletes
#   all nodes from all other cases.  If a request creates a node from a
#   case, the server will delete any existing nodes that are defined in
#   other cases inside the choice.

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
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module system{
  yang-version 1.1;
  namespace "urn:example:config";
  prefix ex;
  /* Case with container vs leaf */
  container cont {
     description
       "One case is leaf, the other container+leaf, issue when replacing one with the other";
     choice d {
        case d1 {
           container d1c {
              choice d11 {
                leaf d11x{
                  type string;
                }
                leaf d11y{
                  type string;
                }
              }
           }
        }
        case d2 {
           container d2c {
              leaf d2x{
                 type string;
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
      @datamodel, @add:leafref-no-refer, @add:leafref-no-refer, cli_auto_del();
      all("Delete whole candidate configuration"), delete_all("candidate");
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
discard("Discard edits (rollback 0)"), discard_changes();

show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "text", true, false);{
            cli("Show configuration as CLI commands"), cli_show_auto_mode("candidate", "cli", true, false, "report-all", "set ");
            xml("Show configuration as XML"), cli_show_auto_mode("candidate", "xml", true, false, NULL);
    }
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

# replace

new "set d1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>
<cont xmlns=\"urn:example:config\">
<d1c>
<d11x>aaa</d11x>
</d1c>
</cont>
</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "replace d2 top"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config>
<cont xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">
<d2c nc:operation='replace'><d2x>bbb</d2x></d2c>
</cont>
</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check d2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<cont xmlns=\"urn:example:config\"><d2c><d2x>bbb</d2x></d2c></cont>" ""

new "replace d1 part"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config>
<cont xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">
<d1c><d11x nc:operation='replace'>ccc</d11x></d1c>
</cont>
</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check d1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<cont xmlns=\"urn:example:config\"><d1c><d11x>ccc</d11x></d1c></cont>" ""

# merge
new "merge d2 part"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config>
<cont xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">
<d2c><d2x nc:operation='merge'>ddd</d2x></d2c>
</cont>
</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check d2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<cont xmlns=\"urn:example:config\"><d2c><d2x>ddd</d2x></d2c></cont>" ""

# create
new "create d1 part"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config>
<cont xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">
<d1c><d11x nc:operation='create'>eee</d11x></d1c>
</cont>
</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check d1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<cont xmlns=\"urn:example:config\"><d1c><d11x>eee</d11x></d1c></cont>" ""

# remove
new "remove d2 part"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config>
<cont xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">
<d2c><d2x nc:operation='remove'>ddd</d2x></d2c>
</cont>
</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "check d1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<cont xmlns=\"urn:example:config\"><d1c><d11x>eee</d11x></d1c></cont>" ""

# delete
new "delete d2 part"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>none</default-operation><config>
<cont xmlns=\"urn:example:config\" xmlns:nc=\"${BASENS}\">
<d2c><d2x nc:operation='delete'>ddd</d2x></d2c>
</cont>
</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-severity>error</error-severity><error-message>Data does not exist; cannot delete resource</error-message></rpc-error></rpc-reply>"

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
