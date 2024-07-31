#!/usr/bin/env bash
# Datastore system only config test
# see https://github.com/clicon/clixon/pull/534 and extension system-only-config
# Test uses a "standard" yang and a "local" yang which augmanets the standard

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
clispec=$dir/automode.cli

fstandard=$dir/clixon-standard.yang
flocal=$dir/clixon-local.yang

CFD=$dir/conf.d
test -d $CFD || mkdir -p $CFD

AUTOCLI=$(autocli_config clixon-\* kw-nokey false)

# Well-known digest of mount-point xpath
subfilename=9121a04a6f67ca5ac2184286236d42f3b7301e97.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_CONFIGDIR>$CFD</CLICON_CONFIGDIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${dir}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$flocal</CLICON_YANG_MAIN_FILE>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_NETCONF_MONITORING>true</CLICON_NETCONF_MONITORING>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
  <CLICON_STREAM_DISCOVERY_RFC5277>true</CLICON_STREAM_DISCOVERY_RFC5277>
  <CLICON_YANG_SCHEMA_MOUNT>true</CLICON_YANG_SCHEMA_MOUNT>
</clixon-config>
EOF

cat <<EOF > $CFD/autocli.xml
<clixon-config xmlns="http://clicon.org/config">
  <autocli>
    <module-default>false</module-default>
     <list-keyword-default>kw-nokey</list-keyword-default>
     <grouping-treeref>true</grouping-treeref>
     <rule>
        <name>include clixon</name>
        <operation>enable</operation>
        <module-name>clixon-*</module-name>
     </rule>
  </autocli>
</clixon-config>
EOF

# A "standard" YANG
cat <<EOF > $fstandard
module clixon-standard{
  yang-version 1.1;
  namespace "urn:example:std";
  prefix std;
  grouping system-only-group {
     description
        "A grouping containing a system-only field, corresponding to
         a standard module, which gets augmented by a local yang";
     leaf system-only-data {
        description
           "System-only config data";
        type string;
     }
  }
  grouping store-grouping {
     container keys {
        list key {
           key "name";
           leaf name {
              type string;
           }
           uses system-only-group;
        }
     }
  }
  container store {
     description "top-level";
     uses store-grouping;
  }
}
EOF

# A "local" YANG
cat <<EOF > $flocal
module clixon-mount1{
   yang-version 1.1;
   namespace "urn:example:local";
   prefix local;
   import clixon-lib {
      prefix cl;
   }
   import clixon-standard {
      prefix std;
   }
   augment "/std:store/std:keys/std:key/std:system-only-data" {
      cl:system-only-config {
         description
            "Marks system-only-config data";
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
delete("Delete a configuration item") @datamodel, cli_auto_del();
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_auto_mode("candidate", "xml", true, false);{
            xml("Show configuration as XML"), cli_show_auto_mode("candidate", "xml", false, false);
            cli("Show configuration as CLI commands"), cli_show_auto_mode("candidate", "cli", false, false, "report-all", "set ");
            netconf("Show configuration as netconf edit-config operation"), cli_show_auto_mode("candidate", "netconf", false, false);
            text("Show configuration as text"), cli_show_auto_mode("candidate", "text", false, false);
            json("Show configuration as JSON"), cli_show_auto_mode("candidate", "json", false, false);
    }
    state("Show configuration and state"), cli_show_auto_mode("running", "xml", false, true);
    compare("Compare candidate and running databases"), compare_dbs("running", "candidate", "xml");
}
EOF

# Check content of db
# Args:
# 0: dbname
function check_db()
{
    dbname=$1

    sudo chmod 755 $dir/${dbname}_db
    sudo rm -f $dir/x_db
    cat <<EOF > $dir/x_db
<config>
   <store xmlns="urn:example:std">
      <keys>
         <key>
            <name>a</name>
         </key>
      </keys>
   </store>
</config>
EOF
    new "Check ${dbname}_db"
    #    ret=$(diff $dir/x_db $dir/${dbname}_db)
    ret=$(diff $dir/x_db $dir/${dbname}_db)
    if [ $? -ne 0 ]; then
        #        err "$(cat $dir/x_db)" "$(cat $dir/${dbname}_db)"
        err "$(cat $dir/x_db)" "$(cat $dir/${dbname}_db)"
    fi
}

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

new "Add mydata"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data></key></keys></store></config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check mydata not in candidate"
check_db candidate

new "Get mydata from candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data></key></keys></store></data></rpc-reply>"

new "Commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check mydata not in running"
check_db running

new "Get mydata from running"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data></key></keys></store></data></rpc-reply>"

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

sudo rm -rf $dir

new "endtest"
endtest
