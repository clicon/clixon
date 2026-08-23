#!/usr/bin/env bash
# Test of NACM (RFC 8341) data-node rules on RFC 8528 YANG schema mount-points where the
# mount-points mount different revisions of the same YANG module.
# The same NACM rules must be enforced on all mount-points, regardless of which revision of
# the module is mounted.
# Two mount-points are used, named as the revision they mount: 2023-01-01 and 2024-01-01.
# The backend is started with -R which makes it use the key of the list enclosing the
# mount-point as revision in the mounted yang-library.
# The two revisions differ in YANG order: the 2024-01-01 revision has an extra top-level
# container declared before mymount0, and an extra leaf declared before mylist0.
# See https://github.com/clicon/clixon-controller/issues/251

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/nacm_mount_revision.xml
fyang=$dir/clixon-example.yang
fyang0=$dir/clixon-mount0@2023-01-01.yang
fyang1=$dir/clixon-mount0@2024-01-01.yang

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
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_VALIDATE_STATE_XML>true</CLICON_VALIDATE_STATE_XML>
  <CLICON_YANG_SCHEMA_MOUNT>true</CLICON_YANG_SCHEMA_MOUNT>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_CREDENTIALS>none</CLICON_NACM_CREDENTIALS>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
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
  container top{
    list mylist{
      key name;
      leaf name{
        type string;
      }
      container mnt {
        presence "Otherwise mount-point is not visible";
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
  revision 2023-01-01;
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

# Same module name and namespace as $fyang0 but a later revision.
# The extra container is declared before mymount0, and the extra leaf before mylist0, which
# gives mymount0 and mylist0/mylist1 another YANG order than in the 2023-01-01 revision
cat <<EOF > $fyang1
module clixon-mount0{
  yang-version 1.1;
  namespace "urn:example:mount0";
  prefix m0;
  revision 2024-01-01;
  container extra{
    leaf value{
      type string;
    }
  }
  container mymount0{
    leaf descr{
      type string;
    }
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

# The groups are slightly modified from RFC8341 A.1 ($USER added in admin group)
# Note that the paths of the rules have no key in ex:mylist, ie they apply to all
# mount-points, regardless of which revision they mount.
# The "limited" group is permitted mylist0 only (default deny)
# The "guest" group is denied mylist1 but permitted everything else
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
         <name>permit mylist0</name>
         <path xmlns:ex="urn:example:clixon" xmlns:m0="urn:example:mount0">
            /ex:top/ex:mylist/ex:mnt/m0:mymount0/m0:mylist0
         </path>
         <access-operations>*</access-operations>
         <action>permit</action>
       </rule>
       <rule>
         <name>permit exec</name>
         <module-name>*</module-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
       </rule>
     </rule-list>

     <rule-list>
       <name>guest deny</name>
       <group>guest</group>
       <rule>
         <name>deny mylist1</name>
         <path xmlns:ex="urn:example:clixon" xmlns:m0="urn:example:mount0">
            /ex:top/ex:mylist/ex:mnt/m0:mymount0/m0:mylist1
         </path>
         <access-operations>*</access-operations>
         <action>deny</action>
       </rule>
       <rule>
         <name>permit rest</name>
         <module-name>*</module-name>
         <access-operations>*</access-operations>
         <action>permit</action>
       </rule>
     </rule-list>
   </nacm>
EOF
)

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg -- -m clixon-mount0 -M urn:example:mount0 -R"
    start_backend -s init -f $cfg -- -m clixon-mount0 -M urn:example:mount0 -R
fi

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg -- -m clixon-mount0 -M urn:example:mount0 -R
fi

new "wait restconf"
wait_restconf

new "Add two mountpoints, one per revision"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>2023-01-01</name><mnt/></mylist><mylist><name>2024-01-01</name><mnt/></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check mount-point 2023-01-01 mounts revision 2023-01-01"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2023-01-01/mnt)" 0 "HTTP/$HVER 200" "<name>clixon-mount0</name><namespace>urn:example:mount0</namespace><revision>2023-01-01</revision>"

new "Check mount-point 2024-01-01 mounts revision 2024-01-01"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2024-01-01/mnt)" 0 "HTTP/$HVER 200" "<name>clixon-mount0</name><namespace>urn:example:mount0</namespace><revision>2024-01-01</revision>"

new "Check 2024-01-01 only accepts the leaf added in that revision"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>2023-01-01</name><mnt><mymount0 xmlns=\"urn:example:mount0\"><descr>foo</descr></mymount0></mnt></mylist></top></config></edit-config></rpc>" "<rpc-error>" "" "$fyang0"

new "discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "auth set authentication config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Add data to both mounts"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><mylist><name>2023-01-01</name><mnt><mymount0 xmlns=\"urn:example:mount0\"><mylist0><name0>x0</name0></mylist0><mylist1><name1>x1</name1></mylist1></mymount0></mnt></mylist><mylist><name>2024-01-01</name><mnt><mymount0 xmlns=\"urn:example:mount0\"><mylist0><name0>x0</name0></mylist0><mylist1><name1>x1</name1></mylist1></mymount0></mnt></mylist></top></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Enable nacm"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><nacm xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-acm\"><enable-nacm>true</enable-nacm></nacm></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# admin: sees everything on both mount-points
new "restconf admin read revision 2023-01-01 mount, expect all"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2023-01-01/mnt/clixon-mount0:mymount0)" 0 "HTTP/$HVER 200" '<mylist0><name0>x0</name0></mylist0>' '<mylist1><name1>x1</name1></mylist1>'

new "restconf admin read revision 2024-01-01 mount, expect all"
expectpart "$(curl -u andy:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2024-01-01/mnt/clixon-mount0:mymount0)" 0 "HTTP/$HVER 200" '<mylist0><name0>x0</name0></mylist0>' '<mylist1><name1>x1</name1></mylist1>'

# limited: permit rule on mylist0 only, must apply to both mount-points
new "restconf limited read revision 2023-01-01 mount, expect mylist0 only"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2023-01-01/mnt/clixon-mount0:mymount0)" 0 "HTTP/$HVER 200" '<mylist0><name0>x0</name0></mylist0>' --not-- '<mylist1><name1>x1</name1></mylist1>'

new "restconf limited read revision 2024-01-01 mount, expect mylist0 only"
expectpart "$(curl -u wilma:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2024-01-01/mnt/clixon-mount0:mymount0)" 0 "HTTP/$HVER 200" '<mylist0><name0>x0</name0></mylist0>' --not-- '<mylist1><name1>x1</name1></mylist1>'

# guest: deny rule on mylist1, must apply to both mount-points
new "restconf guest read revision 2023-01-01 mount, expect no mylist1"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2023-01-01/mnt/clixon-mount0:mymount0)" 0 "HTTP/$HVER 200" '<mylist0><name0>x0</name0></mylist0>' --not-- '<mylist1><name1>x1</name1></mylist1>'

new "restconf guest read revision 2024-01-01 mount, expect no mylist1"
expectpart "$(curl -u guest:bar $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2024-01-01/mnt/clixon-mount0:mymount0)" 0 "HTTP/$HVER 200" '<mylist0><name0>x0</name0></mylist0>' --not-- '<mylist1><name1>x1</name1></mylist1>'

# write, on the mount-point using the later revision
new "restconf limited write mylist0 in revision 2024-01-01 mount, expect ok"
expectpart "$(curl -u wilma:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2024-01-01/mnt/clixon-mount0:mymount0 -d '<mylist0 xmlns="urn:example:mount0"><name0>wilma</name0></mylist0>')" 0 "HTTP/$HVER 201"

new "restconf limited write mylist1 in revision 2024-01-01 mount, expect fail"
expectpart "$(curl -u wilma:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2024-01-01/mnt/clixon-mount0:mymount0 -d '<mylist1 xmlns="urn:example:mount0"><name1>wilma</name1></mylist1>')" 0 "HTTP/$HVER 403" "access-denied"

new "restconf guest write mylist1 in revision 2024-01-01 mount, expect fail"
expectpart "$(curl -u guest:bar $CURLOPTS -X POST -H "Content-Type: application/yang-data+xml" $RCPROTO://localhost/restconf/data/clixon-example:top/mylist=2024-01-01/mnt/clixon-mount0:mymount0 -d '<mylist1 xmlns="urn:example:mount0"><name1>guest</name1></mylist1>')" 0 "HTTP/$HVER 403" "access-denied"

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
