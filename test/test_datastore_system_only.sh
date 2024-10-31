#!/usr/bin/env bash
# Datastore system only config test
# see https://github.com/clicon/clixon/pull/534 and extension system-only-config
# Test uses a "standard" yang and a "local" yang which augments the standard

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

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
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
  <CLICON_XMLDB_SYSTEM_ONLY_CONFIG>true</CLICON_XMLDB_SYSTEM_ONLY_CONFIG>
  <CLICON_NETCONF_MONITORING>true</CLICON_NETCONF_MONITORING>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
  <CLICON_STREAM_DISCOVERY_RFC5277>true</CLICON_STREAM_DISCOVERY_RFC5277>
  <CLICON_YANG_SCHEMA_MOUNT>true</CLICON_YANG_SCHEMA_MOUNT>
  $RESTCONFIG
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
     leaf normal-data {
        description
           "Normal config data";
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
module clixon-local{
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

# Reference files: What is expected in the datastore
cat <<EOF > $dir/x_db_xml
<config>
   <store xmlns="urn:example:std">
      <keys>
         <key>
            <name>a</name>
            <normal-data>otherdata</normal-data>
         </key>
      </keys>
   </store>
</config>
EOF

# Same in JSON (but broken)
cat <<EOF > $dir/x_db_json
{
   "config": {
      "clixon-standard:store": {
         "keys": {
            "key": [
               {
                  "name": "a",
                  "normal-data": "otherdata"
               }
            ]
         }
      },
      "ietf-netconf-acm:nacm": {
         "enable-nacm": true,
         "read-default": "permit",
         "write-default": "deny",
         "exec-default": "permit",
         "enable-external-groups": true
      }
   }
}
EOF

# What is expected in the system-only-config file (simulated system)
cat <<EOF > $dir/y_db
<store xmlns="urn:example:std">
   <keys>
      <key>
         <name>a</name>
         <system-only-data>mydata</system-only-data>
      </key>
   </keys>
</store>
EOF

# Check content of db
# Args:
# 1: dbname
# 2: system  true/false check in system or not (only after commit)
# 3: format  xml/json
function check_db()
{
    dbname=$1
    system=$2
    format=$3

    sudo chmod 755 $dir/${dbname}_db

    new "Check not in ${dbname}_db"
    ret=$(diff $dir/x_db_$format $dir/${dbname}_db)
    if [ $? -ne 0 ]; then
        err "$(cat $dir/x_db_$format)" "$(cat $dir/${dbname}_db)"
    fi

    if $system; then
        new "Check $dir/system-only.xml"
        ret=$(diff $dir/y_db $dir/system-only.xml)
        if [ $? -ne 0 ]; then
            err "$(cat $dir/y_db)" "$(cat $dir/system-only.xml)"
        fi
    else
        new "Check no $dir/system-only.xml"
        if [ -s $dir/system-only.xml ]; then
            err "No file" "$(cat $dir/system-only.xml)"
        fi
    fi
}

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
fi

sudo rm -f $dir/system-only.xml

if [ $BE -ne 0 ]; then
    new "start backend -s init -f $cfg -- -o store/keys/key/system-only-data -O $dir/system-only.xml"
    start_backend -s init -f $cfg -- -o store/keys/key/system-only-data -O $dir/system-only.xml
fi

new "wait backend 1"
wait_backend

new "Add mydata"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data></key></keys></store></config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add normal data"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><store xmlns=\"urn:example:std\"><keys><key><name>a</name><normal-data>otherdata</normal-data></key></keys></store></config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check mydata present, but not in candidate datastore"
check_db candidate false xml

new "Get mydata from candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data><normal-data>otherdata</normal-data></key></keys></store></data></rpc-reply>"

new "Commit 1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check mydata present, but not in running datastore"
check_db running true xml

new "Get mydata from running"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data><normal-data>otherdata</normal-data></key></keys></store></data></rpc-reply>"

new "Get mydata from candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data><normal-data>otherdata</normal-data></key></keys></store></data></rpc-reply>"

new "Source-of-truth: modify system-only"
sudo chmod 666 $dir/system-only.xml
cat <<EOF > $dir/system-only.xml
<store xmlns="urn:example:std">
   <keys>
      <key>
         <name>a</name>
         <system-only-data>CHANGED</system-only-data>
      </key>
   </keys>
</store>
EOF

new "Get mydata from candidate again"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>CHANGED</system-only-data><normal-data>otherdata</normal-data></key></keys></store></data></rpc-reply>"

new "Restore original"
cp $dir/y_db $dir/system-only.xml

new "Get mydata from candidate again"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data><normal-data>otherdata</normal-data></key></keys></store></data></rpc-reply>"

new "Source-of-truth: modify system-only, then edit"
cat <<EOF > $dir/system-only.xml
<store xmlns="urn:example:std">
   <keys>
      <key>
         <name>a</name>
         <system-only-data>CHANGED</system-only-data>
      </key>
   </keys>
</store>
EOF

new "Add normal data"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><store xmlns=\"urn:example:std\"><keys><key><name>a</name><normal-data>otherdata2</normal-data></key></keys></store></config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Get mydata from candidate expect CHANGED"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>CHANGED</system-only-data><normal-data>otherdata2</normal-data></key></keys></store></data></rpc-reply>"

new "Restore original"
cp $dir/y_db $dir/system-only.xml

new "Discard"
new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Remove mydata"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data nc:operation=\"delete\" xmlns:nc=\"${BASENS}\">mydata</system-only-data></key></keys></store></config><default-operation>none</default-operation></edit-config></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check mydata present, but not in candidate datastore"
check_db candidate true xml

new "Commit 2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Get mydata from running, expecte no system-nly"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><normal-data>otherdata</normal-data></key></keys></store></data></rpc-reply>"

new "Check mydata not present, but not in running datastore"
check_db running false xml

new "Add mydata again"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data></key></keys></store></config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Commit 3"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Restart"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
fi

if [ $BE -ne 0 ]; then
    new "start backend -s running -f $cfg -- -o store/keys/key/system-only-data -O $dir/system-only.xml"
    start_backend -s running -f $cfg -- -o store/keys/key/system-only-data -O $dir/system-only.xml
fi

new "wait backend 2"
wait_backend

new "Check mydata present, but not in running datastore"
check_db running true xml

new "Get mydata from running"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data><normal-data>otherdata</normal-data></key></keys></store></data></rpc-reply>"

new "Remove mydata"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data nc:operation=\"delete\" xmlns:nc=\"${BASENS}\">mydata</system-only-data></key></keys></store></config><default-operation>none</default-operation></edit-config></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Commit 4"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Get mydata from running, expected no system-only"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><normal-data>otherdata</normal-data></key></keys></store></data></rpc-reply>"

new "Check mydata not present, but not in running datastore"
check_db running false xml

new "Restart"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
fi

# Setup startup and saved system-only
sudo cp $dir/x_db_xml $dir/startup_db
sudo cp $dir/y_db $dir/system-only.xml

if [ $BE -ne 0 ]; then
    new "start backend -s startup -f $cfg -- -o store/keys/key/system-only-data -O $dir/system-only.xml"
    start_backend -s startup -f $cfg -- -o store/keys/key/system-only-data -O $dir/system-only.xml
fi

new "wait backend 3"
wait_backend

new "Get mydata from running after startup"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data><normal-data>otherdata</normal-data></key></keys></store></data></rpc-reply>"

new "Restart"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
fi

sudo rm -f $dir/system-only.xml

if [ $BE -ne 0 ]; then
    new "start backend -s init -f $cfg -o CLICON_XMLDB_FORMAT=json -- -o store/keys/key/system-only-data -O $dir/system-only.xml"
    start_backend -s init -f $cfg -o CLICON_XMLDB_FORMAT=json -- -o store/keys/key/system-only-data -O $dir/system-only.xml
fi

new "wait backend 4"
wait_backend

new "Add mydata"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data></key></keys></store></config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add normal data"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><store xmlns=\"urn:example:std\"><keys><key><name>a</name><normal-data>otherdata</normal-data></key></keys></store></config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check mydata present, but not in candidate datastore"
check_db candidate false json

new "Get mydata from candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><store xmlns=\"urn:example:std\"><keys><key><name>a</name><system-only-data>mydata</system-only-data><normal-data>otherdata</normal-data></key></keys></store></data></rpc-reply>"

new "Restart"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
fi

# restconf

sudo rm -f $dir/system-only.xml

if [ $BE -ne 0 ]; then
    new "start backend -s init -f $cfg -- -o store/keys/key/system-only-data -O $dir/system-only.xml"
    start_backend -s init -f $cfg -- -o store/keys/key/system-only-data -O $dir/system-only.xml
fi

new "wait backend 5"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

new "Add system-only data"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-standard:store":{"keys":{"key":[{"name":"a","system-only-data":"mydata"}]}}}' $RCPROTO://localhost/restconf/data)" 0 "HTTP/$HVER 201"

new "Add normal data"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" -d '{"clixon-standard:normal-data":"otherdata"}' $RCPROTO://localhost/restconf/data/clixon-standard:store/keys/key=a)" 0 "HTTP/$HVER 201"

new "Check mydata present, but not in running datastore"
check_db running true xml

new "Check mydata present, but not in candidate datastore"
check_db candidate true xml

new "get"
expectpart "$(curl $CURLOPTS -X GET -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/clixon-standard:store)" 0 "HTTP/$HVER 200" '{"clixon-standard:store":{"keys":{"key":\[{"name":"a","system-only-data":"mydata","normal-data":"otherdata"}\]}}}'

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
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

sudo rm -rf $dir

new "endtest"
endtest
