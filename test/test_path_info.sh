#!/usr/bin/env bash
# rpc config-path-info tests

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/extra.yang
fyang1=$dir/example.yang
fclispec=$dir/clispec.cli

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE></CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
</clixon-config>
EOF

cat <<EOF > $fyang1
module example{
   yang-version 1.1;
   prefix ex;
   namespace "urn:example:clixon";
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
}
EOF

cat <<EOF > $fyang
module extra{
   yang-version 1.1;
   prefix x;
   namespace "urn:example:extra";
   import example{
     prefix ex;
   }
   augment "/ex:table/ex:parameter" {
      leaf extra {
         type string;
      }
   }
}
EOF

cat <<EOF > $fclispec
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %w> ";
CLICON_PLUGIN="example_cli";

# Autocli syntax tree operations
set @datamodel, cli_auto_set();
merge @datamodel, cli_auto_merge();
create @datamodel, cli_auto_create();
delete("Delete a configuration item") @datamodel, @add:leafref-no-refer, cli_auto_del();
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
discard("Discard edits (rollback 0)"), discard_changes();

show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", false, false);
    info("Show details about a configured node: yang, namespaces, etc"){
        @basemodel, @remove:act-list, cli_show_config_info();
    }
}
quit("Quit"), cli_quit();
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "cli set config"
expectpart "$($clixon_cli -1 -f $cfg set table parameter a extra foo)" 0 "^$"

new "cli validate OK"
expectpart "$($clixon_cli -1 -f $cfg validate)" 0 "^$"

new "cli show info"
expectpart "$($clixon_cli -1 -f $cfg show info table parameter a extra foo)" 0 "Module: .* extra" "File: .* $dir/extra.yang" "Namespace: .* urn:example:extra" "Prefix: .* x" "XPath: .* /ex:table/ex:parameter\[ex:name='a'\]/x:extra" "XPath-ns: .* xmlns:ex=\"urn:example:clixon\" xmlns:x=\"urn:example:extra\"" "APIpath: .*  /example:table/parameter=a/extra:extra"

new "netconf show info no path expect error"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><config-path-info $LIBNS/></rpc>" "missing-choice"

RET="<rpc-reply $DEFAULTNS><xml xmlns=\"http://clicon.org/lib\"><table xmlns=\"urn:example:clixon\"><parameter><name>a</name><extra xmlns=\"urn:example:extra\"/></parameter></table></xml><api-path xmlns=\"http://clicon.org/lib\">/example:table/parameter=a/extra:extra</api-path><xpath xmlns=\"http://clicon.org/lib\" xmlns:ex=\"urn:example:clixon\" xmlns:x=\"urn:example:extra\">/ex:table/ex:parameter\[ex:name='a'\]/x:extra</xpath><namespace-context xmlns=\"http://clicon.org/lib\"><namespace><prefix>ex</prefix><ns>urn:example:clixon</ns></namespace><namespace><prefix>x</prefix><ns>urn:example:extra</ns></namespace></namespace-context><symbol xmlns=\"http://clicon.org/lib\">extra</symbol><prefix xmlns=\"http://clicon.org/lib\">x</prefix><ns xmlns=\"http://clicon.org/lib\">urn:example:extra</ns><module xmlns=\"http://clicon.org/lib\">extra</module><filename xmlns=\"http://clicon.org/lib\">$dir/extra.yang</filename></rpc-reply>"

new "netconf show info api-path"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><config-path-info $LIBNS><api-path>/example:table/parameter=a/extra:extra</api-path></config-path-info></rpc>" "$RET"

new "netconf show info xpath"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><config-path-info $LIBNS><xpath>/ex:table/ex:parameter[ex:name='a']/x:extra</xpath></config-path-info></rpc>" "$RET"

new "netconf show info xpath + nsc"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><config-path-info $LIBNS><xpath>/qx:table/qx:parameter[qx:name='a']/w:extra</xpath><namespace-context><namespace><prefix>qx</prefix><ns>urn:example:clixon</ns></namespace><namespace><prefix>w</prefix><ns>urn:example:extra</ns></namespace></namespace-context></config-path-info></rpc>" "$RET"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
    sudo pkill -u root -f clixon_backend
fi

rm -rf $dir

new "endtest"
endtest
