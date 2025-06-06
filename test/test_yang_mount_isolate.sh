#!/usr/bin/env bash
# Test for isolating modules between mount-points.
# That is, so that two modules with same name, revision and namespaces can have different content
# in two separate mount-points.
# Note the mylabel domain is hardcoded in example_backend.c ca_yang_mount callback

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_mount.xml
clispec=$dir/automode.cli
test -d $dir/main || mkdir $dir/main
fyang=$dir/main/clixon-example.yang
test -d $dir/domains/mylabel || mkdir -p $dir/domains/mylabel
#fyang0=$dir/domains/mylabel/clixon-mount0.yang
fyang0=$dir/domains/mylabel/clixon-example.yang
fyang1=$dir/domains/mylabel/clixon-mount1.yang
fyang2=$dir/domains/mylabel/clixon-mount2.yang

CFD=$dir/conf.d
test -d $CFD || mkdir -p $CFD

AUTOCLI=$(autocli_config clixon-\* kw-nokey false)
if [ $? -ne 0 ]; then
    err1 "Error when generating certs"
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_CONFIGDIR>$CFD</CLICON_CONFIGDIR>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${dir}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_YANG_DOMAIN_DIR>$dir/domains</CLICON_YANG_DOMAIN_DIR>
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

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  import ietf-yang-schema-mount {
    prefix yangmnt;
  }
  container top{
    list mylist{
      key name;
      leaf name{
        type string;
      }
      container root{
         presence "Otherwise root is not visible";
         yangmnt:mount-point "mylabel"{
            description "Root for other yang models";
         }
      }
    }
  }
}
EOF

cat <<EOF > $fyang0
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix m0;
  import clixon-mount1 {
     prefix m1;
  }
  import clixon-mount2 {
     prefix m2;
  }
}
EOF

cat <<EOF > $fyang1
module clixon-mount1{
  yang-version 1.1;
  namespace "urn:example:mount1";
  prefix m1;
  container mount1{
    list mylist1{
      key name1;
      leaf name1{
        type string;
      }
    }
  }
}
EOF

cat <<EOF > $fyang2
module clixon-mount2{
  yang-version 1.1;
  namespace "urn:example:mount2";
  prefix m2;
  import clixon-mount1 {
     prefix m1;
  }
  grouping ag2 {
     leaf option2{
        type string;
     }
  }
  grouping ag1 {
     container options {
        leaf option1{
           type string;
        }
        uses ag2;
     }
  }
  augment /m1:mount1/m1:mylist1 {
     uses ag1;
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
delete("Delete a configuration item") @datamodel, @add:leafref-no-refer, cli_auto_del();
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
}
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg -- -m clixon-example -M urn:example:clixon"
    start_backend -s init -f $cfg -- -m clixon-example -M urn:example:clixon
fi

new "wait backend"
wait_backend

new "Add two mountpoints: x and y"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root/></mylist><mylist><name>y</name><root/></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Retrieve schema-mounts with <get> Operation"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><schema-mounts xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-schema-mount\"></schema-mounts></filter></get></rpc>" "<rpc-reply $DEFAULTNS><data><schema-mounts xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-schema-mount\"><mount-point><module>clixon-example</module><label>mylabel</label><config>true</config><inline/></mount-point></schema-mounts></data></rpc-reply>"

new "get yang-lib at mountpoint"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><top xmlns=\"urn:example:clixon\"><mylist/></top>></filter></get></rpc>" "<rpc-reply $DEFAULTNS><data><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><yang-library xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\"><module-set><name>mylabel</name><module><name>clixon-example</name><namespace>urn:example:clixon</namespace></module></module-set></yang-library></root></mylist><mylist><name>y</name><root><yang-library xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\"><module-set><name>mylabel</name><module><name>clixon-example</name><namespace>urn:example:clixon</namespace></module></module-set></yang-library></root></mylist></top></data></rpc-reply>"

new "Add data to mounts"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x1</name1></mylist1></mount1></root></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add mounted augment data 2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x1</name1><options xmlns=\"urn:example:mount2\"><option2>bar</option2></options></mylist1></mount1></root></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "get mounted augment data"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x1</name1><options xmlns=\"urn:example:mount2\"><option2>bar</option2></options></mylist1></mount1></root></mylist><mylist><name>y</name><root/></mylist></top></data></rpc-reply>"

new "cli show config"
expectpart "$($clixon_cli -1 -f $cfg show config xml -- -m clixon-example -M urn:example:clixon)" 0 "<top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x1</name1><options xmlns=\"urn:example:mount2\"><option2>bar</option2></options></mylist1></mount1></root></mylist><mylist><name>y</name><root/></mylist></top>"

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
