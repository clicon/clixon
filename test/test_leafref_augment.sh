#!/usr/bin/env bash
# Yang leafref + augment + grouping taking from a more complex netgate errorcase
# A main yang spec: leafref
# and a secondary yang spec: augment
# module leafref has a primary construct (sender) and a leafref typedef
# module augment has an augment and a grouping from where it uses the leafref typedef
# Which means that you should first have xml such as:
#   <sender>
#      <name>x</name>
#    </sender>
# and you can then track it via for example (extra levels for debugging):
# <sender>
#   <name>y</name>
#   <stub> # original
#      <extra> # augment
#        <track> # grouping
#          <sender>
#             <name>x</name> <----
#          </sender>
#        </track>
#      </extra>
#   </stub> 
# </sender>
#
# There is also test for using prefixes or not, as well as swithcing prefix between the main module and
# it import statement.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang1=$dir/leafref.yang
fyang2=$dir/augment.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang2</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# NOTE prefix "example" used in module different from "ex" used in mport of that module
cat <<EOF > $fyang1
module leafref{
    yang-version 1.1;
    namespace "urn:example:example";
    prefix example;
    typedef sender-ref {
        description "For testing leafref across augment and grouping";
        type leafref {
            path "/ex:sender/ex:name";
            require-instance true;      
        }
    }
    typedef sender-ref-local {
        description "For testing leafref local";
        type leafref {
            path "/example:sender/example:name";
            require-instance true;
        }
    }
    list sender{
        key name;
        leaf name{
           type string;
        }
        container stub{
           description "Here is where augmentation is done";
        }
        leaf ref{
           description "top-level ref (wrong prefix)";
           type sender-ref;
        }
        leaf ref-local{
           description "top-level ref (right prefix)";
           type sender-ref-local;
        }
    }
}
EOF

cat <<EOF > $fyang2
module augment{
    yang-version 1.1;
    namespace "urn:example:augment";
    prefix aug;
    import leafref {
        description "Note different from canonical (leafref module own prefix is 'example'";
        prefix "ex"; 
    }
    grouping attributes {
       container track{
          description "replicates original structure but only references original";
          list sender{
            description "reference using path in typedef";
            key name;
            leaf name{
              type ex:sender-ref;
            }
          }
          list senderdata{
            description "reference using path inline in data (not typedef)";
            key name;
            leaf name{
                type leafref {
                    path "/ex:sender/ex:name";
                    require-instance true;
                 }
            }
          }
       }
    }
    augment "/ex:sender/ex:stub" {
        description "Main leafref/sender stub.";
        container extra{
           presence "ensuring it is there";
           uses attributes;
        }
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
    new "start backend  -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

# Test top-level, default prefix, correct leafref and typedef path
XML=$(cat <<EOF
   <sender xmlns="urn:example:example">
      <name>x</name>
    </sender>
   <sender xmlns="urn:example:example">
      <name>y</name>
      <ref-local>x</ref-local>
   </sender>
EOF
)

# Use augment + explicit prefixes, correct leafref and typedef path
XML=$(cat <<EOF
   <sender xmlns="urn:example:example">
      <name>x</name>
    </sender>
   <sender xmlns="urn:example:example">
      <name>y</name>
      <stub>
         <aug:extra xmlns:aug="urn:example:augment">
           <aug:track>
             <aug:sender>
                <aug:name>x</aug:name>
             </aug:sender>
           </aug:track>
         </aug:extra>
      </stub> 
   </sender>
EOF
)

new "leafref augment+leafref config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$XML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref augment+leafref validate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Use augment, default prefixes, wrong leafref and typedef path
XML=$(cat <<EOF
   <sender xmlns="urn:example:example">
      <name>x</name>
    </sender>
   <sender xmlns="urn:example:example">
      <name>y</name>
      <stub>
         <extra xmlns="urn:example:augment">
           <track>
             <sender>
                <name>xxx</name>
             </sender>
           </track>
         </extra>
      </stub> 
   </sender>
EOF
)

new "leafref augment+leafref config wrong ref"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$XML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref augment+leafref validate wrong ref"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>instance-required</error-app-tag><error-path>/ex:sender/ex:name</error-path><error-info><name>xxx</name></error-info><error-severity>error</error-severity>" ""

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Use augment, default prefixes, correct leafref and in-data path
XML=$(cat <<EOF
   <sender xmlns="urn:example:example">
      <name>x</name>
    </sender>
   <sender xmlns="urn:example:example">
      <name>y</name>
      <stub>
         <extra xmlns="urn:example:augment">
           <track>
             <senderdata>
                <name>x</name>
             </senderdata>
           </track>
         </extra>
      </stub> 
   </sender>
EOF
)

new "leafref augment+leafref config in-data"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$XML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "leafref augment+leafref validate in-data"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

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
