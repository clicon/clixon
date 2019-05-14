#!/bin/bash
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

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fmain</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
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
   container main{
      uses xtra:mygroup;
      leaf x{
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
}
EOF

# Submodule to submodule (transitive)
cat <<EOF > $fsub2
submodule sub2 {
   yang-version 1.1;
   belongs-to sub1 {
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

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

new "netconfig edit main module"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><main xmlns="urn:example:clixon"><x>foo</x><ext>foo</ext></main></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "cli edit main"
expectfn "$clixon_cli -1f $cfg set main x bar" 0 ""

new "cli edit main ext"
expectfn "$clixon_cli -1f $cfg set main ext bar" 0 ""

new "netconfig edit sub1"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><sub1 xmlns="urn:example:clixon"><x>foo</x><ext1>foo</ext1></sub1></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "cli edit sub1"
expectfn "$clixon_cli -1f $cfg set sub1 x bar" 0 ""

new "cli edit sub1 ext"
expectfn "$clixon_cli -1f $cfg set sub1 ext1 bar" 0 ""

new "netconfig edit sub2 module"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><sub2 xmlns="urn:example:clixon"><x>foo</x><ext2>foo</ext2></sub2></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "cli edit sub2"
expectfn "$clixon_cli -1f $cfg set sub2 x fum" 0 ""

new "cli edit sub2 ext"
expectfn "$clixon_cli -1f $cfg set sub2 ext2 fum" 0 ""

new "netconf submodule validate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Now same with restconf
new "restconf edit main"
expectfn 'curl -s -i -X POST http://localhost/restconf/data -d {"main:main":{"x":"foo","ext":"foo"}}' 0 'HTTP/1.1 200 OK'

new "restconf edit sub1"
expectfn 'curl -s -i -X POST http://localhost/restconf/data -d {"main:sub1":{"x":"foo","ext1":"foo"}}' 0 'HTTP/1.1 200 OK'

new "restconf edit sub2"
expectfn 'curl -s -i -X POST http://localhost/restconf/data -d {"main:sub2":{"x":"foo","ext2":"foo"}}' 0 'HTTP/1.1 200 OK'

new "restconf check main/sub1/sub2 contents"
expectfn "curl -s -X GET http://localhost/restconf/data" 0 '{"data": {"main:main": {"ext": "foo","x": "foo"},"main:sub1": {"ext1": "foo","x": "foo"},"main:sub2": {"ext2": "foo","x": "foo"}}}'

new "Kill restconf daemon"
stop_restconf 

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg
sudo pkill -u root -f clixon_backend

rm -rf $dir
