#!/usr/bin/env bash
# Test for RFC8528 YANG Schema Mount + NACM RFC 8341
# clixon-example is top-level, mounts clixon-mount1
# The example extends the main example using -- -m <name> -M <urn> for both backend and cli
# Extensive testing of mounted augment/uses: see fyang0 which includes fyang1+fyang2

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/nacm_mount.xml
clispec=$dir/automode.cli
fyang=$dir/clixon-example.yang
fyang0=$dir/clixon-mount0.yang

# Common NACM scripts
. ./nacm.sh

CFD=$dir/conf.d
test -d $CFD || mkdir -p $CFD

RESTCONFIG=$(restconf_config user false)
if [ $? -ne 0 ]; then
    err1 "Error when generating certs"
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_CONFIGDIR>$CFD</CLICON_CONFIGDIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${dir}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
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
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_CREDENTIALS>none</CLICON_NACM_CREDENTIALS>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
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

cat <<EOF > $CFD/restconf.xml
<clixon-config xmlns="http://clicon.org/config">
  $RESTCONFIG
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
  import ietf-netconf-acm {
    prefix nacm;
  } 
  container top{
    list mylist{
      key name;
      leaf name{
        type string;
      }
      container mnt {
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
module clixon-mount0{
  yang-version 1.1;
  namespace "urn:example:mount0";
  prefix m0;
  container mymount0{
    list mylist0{
      key name0;
      leaf name0{
        type string;
      }
    }
    list mylist1{
      key name1;
      leaf name1{
        type string;
      }
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

# The groups are slightly modified from RFC8341 A.1 ($USER added in admin group)
# The rule-list is from A.4
# Note read-default is set to permit to ensure that deny-nacm is meaningful
RULES=$(cat <<EOF
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>false</enable-nacm>
     <read-default>deny</read-default>
     <write-default>deny</write-default>
     <exec-default>deny</exec-default>

     $NGROUPS

     $NADMIN

     <rule-list>
       <name>limited permit</name>
       <group>limited</group>
       <rule>
         <name>permit get</name>
         <path xmlns:ex="http://clicon.org/config" xmlns:m0="urn:example:mount0">
            /ex:top/ex:mylist/ex:mnt/m0:mymount0/m0:mylist0
         </path>
         <access-operations>*</access-operations>
         <action>permit</action>
         <comment>
           Allow the 'limited' group full access to mylist0.
         </comment>
       </rule>
       <rule>
         <name>permit exec</name>
         <module-name>*</module-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
         <comment>
             Allow invocation of the supported server operations.
         </comment>
       </rule>

     </rule-list>
   </nacm>
EOF
)
#           /ex:top/ex:mylist/ex:mnt/m0:mymount0/m0:mylist0

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg  -- -m clixon-mount0 -M urn:example:mount0"
    start_backend -s init -f $cfg -- -m clixon-mount0 -M urn:example:mount0
fi

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre
    
    new "start restconf daemon"
    start_restconf -f $cfg -- -m clixon-mount0 -M urn:example:mount0
fi

new "wait restconf"
wait_restconf

new "Add mountpoint: x"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><mnt/></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "auth set authentication config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add data to mounts"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><mnt><mymount0 xmlns=\"urn:example:mount0\"><mylist0><name0>x0</name0></mylist0><mylist1><name1>x1</name1></mylist1></mymount0></mnt></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Enable nacm"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\"><enable-nacm>true</enable-nacm></nacm></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "get netconf data"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" "<rpc-reply $DEFAULTNS><data><top xmlns=\"urn:example:clixon\"><mylist><name>x</name><mnt><mymount0 xmlns=\"urn:example:mount0\"><mylist0><name0>x0</name0></mylist0><mylist1><name1>x1</name1></mylist1></mymount0></mnt></mylist></top>"

new "restconf admin read mnt ok"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt)" 0 "HTTP/$HVER 200" '<mnt xmlns="urn:example:clixon"><mymount0 xmlns="urn:example:mount0"><mylist0><name0>x0</name0></mylist0><mylist1><name1>x1</name1></mylist1></mymount0><yang-library xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library"><module-set><name>mylabel</name><module><name>clixon-mount0</name><namespace>urn:example:mount0</namespace></module></module-set></yang-library></mnt>'

new "restconf limit read mnt ok"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt)" 0 "HTTP/$HVER 200" '<mnt xmlns="urn:example:clixon"><mymount0 xmlns="urn:example:mount0"><mylist0><name0>x0</name0></mylist0></mymount0></mnt>'

new "restconf guest read mnt access denied"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt)" 0 "HTTP/$HVER 403" '<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>default deny</error-message></error></errors>'

new "restconf admin read mnt mylist0 expect ok"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0/mylist0=x0)" 0 "HTTP/$HVER 200" '<mylist0 xmlns="urn:example:mount0"><name0>x0</name0></mylist0>'

new "restconf admin read mnt mylist1 expect ok"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0/mylist1=x1)" 0 "HTTP/$HVER 200" '<mylist1 xmlns="urn:example:mount0"><name1>x1</name1></mylist1>'

new "restconf limit read mnt mylist0 expect ok"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0/mylist0=x0)" 0 "HTTP/$HVER 200" '<mylist0 xmlns="urn:example:mount0"><name0>x0</name0></mylist0>'

new "restconf limit read mnt mylist0 expect fail"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0/mylist1=x1)" 0 "HTTP/$HVER 404" '<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-type>application</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>Instance does not exist</error-message></error></errors>'

new "restconf guest read mnt mylist0 expect access denied"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0/mylist1=x1)" 0 "HTTP/$HVER 403" '<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>default deny</error-message></error></errors>'

# write
new "restconf admin write mnt mylist0 expect ok"
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0 -d '<mylist0 xmlns="urn:example:mount0"><name0>andy</name0></mylist0>')" 0 "HTTP/$HVER 201"

new "restconf admin write mnt mylist1 expect ok"
expectpart "$(curl -u andy:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0 -d '<mylist1 xmlns="urn:example:mount0"><name1>andy</name1></mylist1>')" 0 "HTTP/$HVER 201"

new "restconf limited write mnt mylist0 expect ok"
expectpart "$(curl -u wilma:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0 -d '<mylist0 xmlns="urn:example:mount0"><name0>wilma</name0></mylist0>')" 0 "HTTP/$HVER 201"

new "restconf limited write mnt mylist1 expect fail"
expectpart "$(curl -u wilma:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0 -d '<mylist1 xmlns="urn:example:mount0"><name1>wilma</name1></mylist1>')" 0 "HTTP/$HVER 403" "access-denied"

new "restconf guest write mnt mylist0 expect fail"
expectpart "$(curl -u guest:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0 -d '<mylist0 xmlns="urn:example:mount0"><name0>guest</name0></mylist0>')" 0 "HTTP/$HVER 403" "access-denied"

new "restconf admin get check"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=x/mnt/clixon-mount0:mymount0)" 0 "HTTP/$HVER 200" '<mylist0><name0>andy</name0></mylist0>' '<mylist0><name0>wilma</name0></mylist0>' '<mylist1><name1>andy</name1></mylist1>' --not-- '<mylist1><name1>wilma</name1></mylist1>' '<mylist0><name0>guest</name0></mylist0>' 

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

rm -rf $dir

new "endtest"
endtest
