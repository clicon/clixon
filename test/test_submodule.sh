#!/usr/bin/env bash
# Yang test of submodules
# Test included submodules and imported extra modules.
# Structure is:
# main -> sub1 -> sub2
#     \xtra  \xtra1 \xtra2
# Tests accesses configuration in main/sub1/sub2 and uses grouping
# from xtra/xtra1 for cli/netconf and restconf

# Note that main/sub1/sub2 is same namespace
# Note also that xtra/xtra2 is referenced by same prefix, which stems
# from a problem is that openconfig-mpls.yang imports:
#    import openconfig-segment-routing { prefix oc-sr; }
# while openconfig-mpls-te.yang re-uses the same prefix:
#    import openconfig-mpls-sr { prefix oc-sr; }

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/submodule.xml
fmain=$dir/main.yang         # Main
fsub1=$dir/sub1.yang         # Submodule of main
fsub2=$dir/sub2.yang         # Submodule of sub-module of main (transitive)
fextra=$dir/extra.yang       # Referenced from main (with same prefix)
fextra1=$dir/extra1.yang     # Referenced from sub1
fextra2=$dir/extra2.yang     # Referenced from sub2

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>main:A</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fmain</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
  $RESTCONFIG
</clixon-config>
EOF

# main
cat <<EOF > $fmain
module main{
   yang-version 1.1;
   prefix ex;
   namespace "urn:example:clixon";

   include sub1;
   import extra{
     description "Uses the same prefix as submodule but for another module";
     prefix xtra;
   }
   revision 2021-03-08;
   feature A{
      description "This test feature is enabled";
   }
   feature B{
      description "This test feature is not enabled";
   }
   container main{
      uses xtra:mygroup;
      leaf x{
        type string;
      }
   }
   /* Augment something in sub module */
   augment /ex:sub2 {
     leaf aug0{
        type string;
     }
   }
}
EOF

# Submodule1
cat <<EOF > $fsub1
submodule sub1 {
   yang-version 1.1;
   belongs-to main {
      prefix ex;
   }
   include sub2;
   import extra1{
     description "Only imported in submodule not in main module";
     prefix xtra;
   }
   container sub1{
      uses xtra:mygroup;
      leaf x{
        type string;
      }
   }
   /* Augment something in module */
   augment /ex:main {
     leaf aug1{
        type string;
     }
   }
   /* Augment something in another submodule */
   augment /ex:sub2 {
     leaf aug2{
        type string;
     }
   }
}
EOF

# Submodule to submodule (transitive)
cat <<EOF > $fsub2
submodule sub2 {
   yang-version 1.1;
   belongs-to main {
      prefix ex;
   }
   import extra2{
     description "Only imported in submodule not in main module";
     prefix xtra;
   }
   container sub2{
      uses xtra:mygroup;
      leaf x{
        type string;
      }
   }
}
EOF

cat <<EOF > $fextra
module extra{
   yang-version 1.1;
   prefix xtra;
   namespace "urn:example:extra";
   grouping mygroup{
     leaf ext{
       type string;
     }
   }
}
EOF

cat <<EOF > $fextra1
module extra1{
   yang-version 1.1;
   prefix xtra1;
   namespace "urn:example:extra1";
   grouping mygroup{
     leaf ext1{
       type string;
     }
   }
}
EOF

cat <<EOF > $fextra2
module extra2{
   yang-version 1.1;
   prefix xtra2;
   namespace "urn:example:extra2";
   grouping mygroup{
     leaf ext2{
       type string;
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
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

new "netconfig edit main module"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><main xmlns=\"urn:example:clixon\"><x>foo</x><ext>foo</ext></main></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "cli edit main"
expectpart "$($clixon_cli -1f $cfg set main x bar)" 0 ""

new "cli edit main ext"
expectpart "$($clixon_cli -1f $cfg set main ext bar)" 0 ""

new "netconfig edit sub1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><sub1 xmlns=\"urn:example:clixon\"><x>foo</x><ext1>foo</ext1></sub1></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "cli edit sub1"
expectpart "$($clixon_cli -1f $cfg set sub1 x bar)" 0 ""

new "cli edit sub1 ext"
expectpart "$($clixon_cli -1f $cfg set sub1 ext1 bar)" 0 ""

new "netconfig edit sub2 module"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><sub2 xmlns=\"urn:example:clixon\"><x>foo</x><ext2>foo</ext2></sub2></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "cli edit sub2"
expectpart "$($clixon_cli -1f $cfg set sub2 x fum)" 0 ""

new "cli edit sub2 ext"
expectpart "$($clixon_cli -1f $cfg set sub2 ext2 fum)" 0 ""

new "netconf submodule validate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Now same with restconf
new "restconf edit main"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data -d '{"main:main":{"x":"foo","ext":"foo"}}')" 0 "HTTP/$HVER 201"

new "restconf edit sub1"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data -d '{"main:sub1":{"x":"foo","ext1":"foo"}}')" 0 "HTTP/$HVER 201"

new "restconf edit sub2"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data -d '{"main:sub2":{"x":"foo","ext2":"foo"}}')" 0 "HTTP/$HVER 201"

new "restconf check main/sub1/sub2 contents"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data?content=config)" 0 "HTTP/$HVER 200" '{"ietf-restconf:data":{"main:main":{"ext":"foo","x":"foo"},"main:sub1":{"ext1":"foo","x":"foo"},"main:sub2":{"ext2":"foo","x":"foo"}'

new "restconf edit augment 0"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/main:sub2 -d '{"main:aug0":"foo"}')" 0 "HTTP/$HVER 201"

# Alternative use PUT
new "restconf PUT augment 1 "
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/main:main/aug1 -d '{"main:aug1":"foo"}')" 0 "HTTP/$HVER 201"

new "restconf PATCH augment 1 "
expectpart "$(curl $CURLOPTS -X PATCH -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/main:main/aug1 -d '{"main:aug1":"foo"}')" 0 "HTTP/$HVER 204"

new "restconf edit augment 2"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/main:sub2 -d '{"main:aug2":"foo"}')" 0 "HTTP/$HVER 201"

new "NETCONF get module state"
expecteof_netconf "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"/yl:yang-library/yl:module-set[yl:name='default']/yl:module[yl:name='main']\" xmlns:yl=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\"/></get></rpc>" "<rpc-reply $DEFAULTNS><data><yang-library xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\"><module-set><name>default</name><module><name>main</name><revision>2021-03-08</revision><namespace>urn:example:clixon</namespace><submodule><name>sub1</name><revision/></submodule><feature>A</feature></module>" ""

new "RESTCONF get module state"
expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data/ietf-yang-library:yang-library/module-set=default/module=main?config=nonconfig)" 0 "HTTP/$HVER 200" "<module xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\"><name>main</name><revision>2021-03-08</revision><namespace>urn:example:clixon</namespace><submodule><name>sub1</name><revision/></submodule><feature>A</feature></module>"

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
    sudo pkill -u root -f clixon_backend
fi

# Set by restconf_config
unset RESTCONFIG

rm -rf $dir

new "endtest"
endtest
