#!/usr/bin/env bash
# Test nmda compare
# See RFC 9144, ietf-nmda-compare.yang
# See Example in Section 5

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/ietf-interfaces.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# From RFC9144 Section 6.
# Modifications from RFC:
# enable is not mandatory
cat <<EOF > $fyang
module ietf-interfaces{
  yang-version 1.1;
  namespace "urn:ietf:params:xml:ns:yang:ietf-interfaces";
  prefix if;
  import ietf-origin{
     prefix or;
  }
  revision 2025-08-01;
  container interfaces {
     description
       "Interface parameters.";
     list interface {
       key "name";
       leaf name {
         type string;
         description
           "The name of the interface.";
       }
       leaf description {
         type string;
         description
           "A textual description of the interface.";
       }
       leaf enabled {
         type boolean;
//         default "true";
         description
           "This leaf contains the configured, desired state of the
            interface.";
       }
       choice mch {
         case first{
           leaf-list ma {
             type int32;
           }
           leaf mb {
             type int32;
           }
         }
         case second{
           leaf-list mc {
             type int32;
           }
         }
       }
     }
     list ordered {
       key "name";
       ordered-by user;
       leaf name {
         type string;
         description
           "The name of the interface.";
       }
     }
   }
}

EOF

# Add candidate, running and commit
function add_commit()
{
    new "Add running and commit"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>${RUNNING}</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf commit"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "Add CANDIDATE"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><default-operation>replace</default-operation><config>${CANDIDATE}</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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

# Modify example in RFC 9144 to uses:
# INTENDED->running (source)
# OPERATIONAL->candidate (target)
# 1) create description
# 2) change enabled true->false

CANDIDATE='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth0</name><description>ip interface</description><enabled>false</enabled></interface></interfaces>'

RUNNING='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces" xmlns:or="urn:ietf:params:xml:ns:yang:ietf-origin"><interface or:origin="or:learned"><name>eth0</name><enabled>true</enabled></interface></interfaces>'

TARGET=/ietf-interfaces:interface=eth0

add_commit

new "compare nomatch" # use no-matching xpath
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS>
     <compare xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"
         xmlns:ds=\"urn:ietf:params:xml:ns:yang:ietf-datastores\">
       <source>ds:running</source>
       <target>ds:candidate</target>
       <xpath-filter
           xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">
         /if:nomatch
       </xpath-filter>
     </compare>
</rpc>" "" "<rpc-reply $DEFAULTNS><no-matches xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"/></rpc-reply>"

# 1) create description
# 2) change enabled true->false
EDIT1="<edit><edit-id>1</edit-id><operation>create</operation><target>${TARGET}/description</target><value><description xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">ip interface</description></value></edit>"
EDIT2="<edit><edit-id>2</edit-id><operation>replace</operation><target>${TARGET}/enabled</target><value><enabled xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">false</enabled></value><source-value><enabled xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">true</enabled></source-value></edit>"

new "compare rfc example" # Section 5
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS>
     <compare xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"
         xmlns:ds=\"urn:ietf:params:xml:ns:yang:ietf-datastores\">
       <source>ds:running</source>
       <target>ds:candidate</target>
       <xpath-filter
           xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">
         /if:interfaces
       </xpath-filter>
     </compare>
</rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" message-id=\"42\"><differences xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"><yang-patch><patch-id>patch</patch-id><comment>diff between running (source) and candidate (target)</comment>${EDIT1}${EDIT2}</yang-patch></differences></rpc-reply>"

# Switch example
# 1) delete description
# 2) change enabled false->true
EDIT1="<edit><edit-id>1</edit-id><operation>delete</operation><target>${TARGET}/description</target><value><description xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">ip interface</description></value></edit>"
EDIT2="<edit><edit-id>2</edit-id><operation>replace</operation><target>${TARGET}/enabled</target><value><enabled xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">true</enabled></value><source-value><enabled xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">false</enabled></source-value></edit>"

new "compare reverse example" # From rfc
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS>
     <compare xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"
         xmlns:ds=\"urn:ietf:params:xml:ns:yang:ietf-datastores\">
       <source>ds:candidate</source>
       <target>ds:running</target>
       <xpath-filter
           xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">
         /if:interfaces
       </xpath-filter>
     </compare>
</rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" message-id=\"42\"><differences xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"><yang-patch><patch-id>patch</patch-id><comment>diff between candidate (source) and running (target)</comment>${EDIT1}${EDIT2}</yang-patch></differences></rpc-reply>"

# Remove last element and switch that to get add/remove of last element
# RUNNING: includes description
RUNNING='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth0</name><description>ip interface</description></interface></interfaces>'

# CANDIDATE: description is removed
CANDIDATE='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth0</name></interface></interfaces>'

EDIT1="<edit><edit-id>1</edit-id><operation>delete</operation><target>${TARGET}/description</target><value><description xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">ip interface</description></value></edit>"

add_commit

new "compare remove last element"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS>
     <compare xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"
         xmlns:ds=\"urn:ietf:params:xml:ns:yang:ietf-datastores\">
       <source>ds:running</source>
       <target>ds:candidate</target>
       <xpath-filter
           xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">
         /if:interfaces
       </xpath-filter>
     </compare>
</rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" message-id=\"42\"><differences xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"><yang-patch><patch-id>patch</patch-id><comment>diff between running (source) and candidate (target)</comment>${EDIT1}</yang-patch></differences></rpc-reply>"

# Switch last element
EDIT1="<edit><edit-id>1</edit-id><operation>create</operation><target>${TARGET}/description</target><value><description xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">ip interface</description></value></edit>"

new "compare add last element"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS>
     <compare xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"
         xmlns:ds=\"urn:ietf:params:xml:ns:yang:ietf-datastores\">
       <source>ds:candidate</source>
       <target>ds:running</target>
       <xpath-filter
           xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">
         /if:interfaces
       </xpath-filter>
     </compare>
</rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" message-id=\"42\"><differences xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"><yang-patch><patch-id>patch</patch-id><comment>diff between candidate (source) and running (target)</comment>${EDIT1}</yang-patch></differences></rpc-reply>"

# Change choice
# mc=17 -> ma=17+mb=72
CANDIDATE='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth0</name><ma>17</ma><mb>72</mb></interface></interfaces>'

RUNNING='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><interface><name>eth0</name><mc>17</mc></interface></interfaces>'

TARGET=/ietf-interfaces:interface=eth0

EDIT1="<edit><edit-id>1</edit-id><operation>delete</operation><target>${TARGET}/mc=17</target><value><mc xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">17</mc></value></edit>"
EDIT2="<edit><edit-id>2</edit-id><operation>create</operation><target>${TARGET}/ma=17</target><value><ma xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">17</ma></value></edit>"
EDIT3="<edit><edit-id>3</edit-id><operation>create</operation><target>${TARGET}/mb</target><value><mb xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">72</mb></value></edit>"

add_commit

new "compare choice"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS>
     <compare xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"
         xmlns:ds=\"urn:ietf:params:xml:ns:yang:ietf-datastores\">
       <source>ds:running</source>
       <target>ds:candidate</target>
       <xpath-filter
           xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">
         /if:interfaces
       </xpath-filter>
     </compare>
</rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" message-id=\"42\"><differences xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"><yang-patch><patch-id>patch</patch-id><comment>diff between running (source) and candidate (target)</comment>${EDIT1}${EDIT2}${EDIT3}</yang-patch></differences></rpc-reply>"

# ordered-by-user reorder
# 0,1,2 (running) -> 2,0,1 (candidate)
# delete 0, add 0
CANDIDATE='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><ordered><name>eth1</name></ordered><ordered><name>eth0</name></ordered></interfaces>'

RUNNING='<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"><ordered><name>eth0</name></ordered><ordered><name>eth1</name></ordered></interfaces>'

TARGET=/ietf-interfaces:ordered=eth0

EDIT1="<edit><edit-id>1</edit-id><operation>delete</operation><target>${TARGET}</target><value><ordered xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><name>eth0</name></ordered></value></edit>"
EDIT2="<edit><edit-id>2</edit-id><operation>create</operation><target>${TARGET}</target><value><ordered xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><name>eth0</name></ordered></value></edit>"

add_commit

new "compare ordered-by user reorder"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS>
     <compare xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"
         xmlns:ds=\"urn:ietf:params:xml:ns:yang:ietf-datastores\">
       <source>ds:running</source>
       <target>ds:candidate</target>
       <xpath-filter
           xmlns:if=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">
         /if:interfaces
       </xpath-filter>
     </compare>
</rpc>" "" "<rpc-reply xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" message-id=\"42\"><differences xmlns=\"urn:ietf:params:xml:ns:yang:ietf-nmda-compare\"><yang-patch><patch-id>patch</patch-id><comment>diff between running (source) and candidate (target)</comment>${EDIT1}${EDIT2}</yang-patch></differences></rpc-reply>"

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
