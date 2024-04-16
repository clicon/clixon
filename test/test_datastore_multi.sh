#!/usr/bin/env bash
# Datastore split test, eg x_db has x.d/ directory with subdirs# ALso test cache bevahour, that unmodified
# subteres are not touched
# For now subdirs only enabled for mointpoints, so this test is with mountpoints as well

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# include err() and new() functions and creates $dir

cfg=$dir/conf_yang.xml
clispec=$dir/automode.cli

fyang=$dir/clixon-example.yang
fyang1=$dir/clixon-mount1.yang

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
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_MULTI>true</CLICON_XMLDB_MULTI>
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
  import clixon-lib {
    prefix cl;
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
         cl:xmldb-split; /* Multi-XMLDB: split datastore here */
      }
    }
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
         leaf value1 {
            type string;
         }
      }
   }
   container extra{
      leaf extraval{
         type string;
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
# 1: subfile
function check_db()
{
    dbname=$1
    subfile=$2

    sudo chmod o+r $dir/${dbname}_db
    sudo chmod o+r $dir/${dbname}.d/$subfile

    sudo rm -f $dir/x_db
    cat <<EOF > $dir/x_db
<config>
   <top xmlns="urn:example:clixon">
      <mylist>
         <name>x</name>
         <root xmlns:cl="http://clicon.org/lib" cl:link="$subfile"/>
      </mylist>
   </top>
</config>
EOF
    new "Check ${dbname}_db"
    ret=$(diff $dir/x_db $dir/${dbname}_db)
    if [ $? -ne 0 ]; then
        err "$(cat $dir/x_db)" "$(cat $dir/${dbname}_db)"
    fi
    cat <<EOF > $dir/x_subfile
<mount1 xmlns="urn:example:mount1">
   <mylist1>
      <name1>x1</name1>
   </mylist1>
</mount1>
<extra xmlns="urn:example:mount1">
   <extraval>foo</extraval>
</extra>
EOF
    new "Check ${dbname}.d/$subfile"
    ret=$(diff $dir/x_subfile $dir/${dbname}.d/$subfile)
    if [ $? -ne 0 ]; then
        err "$(cat $dir/x_subfile)" "$(cat $dir/${dbname}.d/$subfile)"
    fi
}

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg -- -m clixon-mount1 -M urn:example:mount1"
    start_backend -s init -f $cfg -- -m clixon-mount1 -M urn:example:mount1
fi

new "wait backend"
wait_backend

new "Add mountpoint x "
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root/></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add data to mount x"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x1</name1></mylist1></mount1><extra xmlns=\"urn:example:mount1\"><extraval>foo</extraval></extra></root></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check candidate after edit"
check_db candidate ${subfilename}

s0=$(stat -c "%Y" $dir/candidate.d/${subfilename})
sleep 1

new "Add 2nd data to mount x"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x2</name1><value1>x2value</value1></mylist1></mount1></root></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check candidate subfile changed"
s1=$(stat -c "%Y" $dir/candidate.d/${subfilename})
if [ $s0 -eq $s1 ]; then
    err "Timestamp changed" "$s0 = $s1"
fi

sleep 1

new "Change existing value in mount x"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x2</name1><value1>x2new</value1></mylist1></mount1></root></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check candidate subfile changed"
s2=$(stat -c "%Y" $dir/candidate.d/${subfilename})
if [ $s1 -eq $s2 ]; then
    err "Timestamp changed" "$s1 = $s2"
fi

sleep 1

new "Add data to top-level (not mount)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>y</name></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check candidate subfile not changed"
s3=$(stat -c "%Y" $dir/candidate.d/${subfilename})
if [ $s2 -ne $s3 ]; then
    err "Timestamp not changed" "$s2 != $s3"
fi

sleep 1

new "Delete leaf"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\" xmlns:nc=\"${BASENS}\"><mylist1><name1>x2</name1><value1 nc:operation=\"delete\">x2new</value1></mylist1></mount1></root></mylist></top></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check candidate subfile changed"
s4=$(stat -c "%Y" $dir/candidate.d/${subfilename})
if [ $s4 -eq $s3 ]; then
    err "Timestamp changed" "$s4 = $s3"
fi

sleep 1

new "Delete node"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\" xmlns:nc=\"${BASENS}\"><mylist1 nc:operation=\"delete\"><name1>x2</name1></mylist1></mount1></root></mylist></top></config><default-operation>none</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check candidate subfile changed"
s4=$(stat -c "%Y" $dir/candidate.d/${subfilename})
if [ $s4 -eq $s3 ]; then
    err "Timestamp changed" "$s4 = $s3"
fi

new "Reset secondary adds"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x1</name1></mylist1></mount1><extra xmlns=\"urn:example:mount1\"><extraval>foo</extraval></extra></root></mylist></top></config><default-operation>replace</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit 2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check candidate after commit"
check_db candidate ${subfilename}

new "Check running after commit"
check_db running ${subfilename}

new "cli show config"
expectpart "$($clixon_cli -1 -f $cfg show config xml -- -m clixon-mount1 -M urn:example:mount1)" 0 "<top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x1</name1></mylist1></mount1><extra xmlns=\"urn:example:mount1\"><extraval>foo</extraval></extra></root></mylist></top>"

s0=$(stat -c "%Y" $dir/running.d/${subfilename})
new "Change mount data"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x1</name1><value1>foo</value1></mylist1></mount1></root></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

sleep 1

new "netconf commit 3"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check running subfile changed"
s1=$(stat -c "%Y" $dir/running.d/${subfilename})
if [ $s0 -eq $s1 ]; then
    err "Timestamp changed" "$s0 = $s1"
fi

new "Add data to top-level (not mount)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>y</name></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit 4"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

sleep 1

new "Check running subfile not changed"
s2=$(stat -c "%Y" $dir/running.d/${subfilename})
if [ $s1 -ne $s2 ]; then
    err "Timestamp not changed" "$s1 != $s2"
fi

new "Reset secondary adds"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><root><mount1 xmlns=\"urn:example:mount1\"><mylist1><name1>x1</name1></mylist1></mount1><extra xmlns=\"urn:example:mount1\"><extraval>foo</extraval></extra></root></mylist></top></config><default-operation>replace</default-operation></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit 5"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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

new "Check running before restart"
check_db running ${subfilename}

echo "-s running -f $cfg -- -m clixon-mount1 -M urn:example:mount1"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s running -f $cfg -- -m clixon-mount1 -M urn:example:mount1"
    start_backend -s running -f $cfg -- -m clixon-mount1 -M urn:example:mount1
fi

new "Check running after restart"
check_db running ${subfilename}

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

unset dbname
unset filename

new "endtest"
endtest
