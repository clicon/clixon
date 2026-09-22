#!/usr/bin/env bash
# Regression test for issue #691:
# "Deleting a list entry fails with 'Missing mandatory XML <leaf> node' for
# data the transaction never touched."

s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example
cfg=$dir/conf.xml
fyang=$dir/test691.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/backend.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module test691{
   yang-version 1.1;
   namespace "urn:example:test691";
   prefix t;
   revision 2024-01-01;

   container sectionE {
      leaf unrelated {
         type string;
         mandatory true;
      }
      container innerE {
         leaf marker {
            type string;
         }
         list entry {
            key name;
            leaf name {
               type string;
            }
         }
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
fi

# ---------------------------------------------------------------------------
# Seed running_db directly on disk (bypassing edit-config/commit/validate
# entirely) with sectionE/innerE/{marker,entry[e1]} present and "unrelated"
# absent. Then start with -s none, which loads running as-is without
# validating it.
# ---------------------------------------------------------------------------
cat <<EOF > $dir/running_db
<config>
  <sectionE xmlns="urn:example:test691">
    <innerE>
      <marker>present</marker>
      <entry><name>e1</name></entry>
    </innerE>
  </sectionE>
</config>
EOF

if [ $BE -ne 0 ]; then
    new "start backend -s none (load seeded running_db without validating)"
    start_backend -s none -f $cfg
fi

new "wait backend"
wait_backend

new "Sanity: running db loaded as seeded (unrelated absent, entry[e1] present)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><data><sectionE xmlns=\"urn:example:test691\"><innerE><marker>present</marker><entry><name>e1</name></entry></innerE></sectionE></data></rpc-reply>"

# candidate does not automatically mirror running -- copy explicitly so the
# edit-config below has entry[e1] to delete.
new "copy-config running -> candidate"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><copy-config><source><running/></source><target><candidate/></target></copy-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# ---------------------------------------------------------------------------
# E1: delete the entire innerE/entry[e1] entry (unrelated to "unrelated")
# and commit.
# Bug:   commit fails with "Missing mandatory XML unrelated node" -- data
#        this transaction never touched.
# Fixed: commit succeeds -- deleting entry[e1] cannot affect whether
#        "unrelated" exists two levels up.
# ---------------------------------------------------------------------------
new "E1: delete innerE/entry[e1] (sectionE/unrelated untouched)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><edit-config><target><candidate/></target>
     <config>
       <sectionE xmlns=\"urn:example:test691\">
         <innerE>
           <entry xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"
                  nc:operation=\"delete\">
             <name>e1</name>
           </entry>
         </innerE>
       </sectionE>
     </config>
   </edit-config></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "E1: commit after deleting entry[e1] -- expect ok (not blocked by unrelated sectionE/unrelated)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><commit/></rpc>" \
  "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>" \
  --not-- "<rpc-error>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
