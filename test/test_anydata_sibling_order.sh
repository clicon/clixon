#!/usr/bin/env bash
# Regression test for: edit-config of an anydata node breaks sibling order,
# causing duplicate list entries (PR #708).
#
# A node whose if-feature is disabled is treated as anydata. An add with xml_new()
# appends it as the LAST child of the parent x0p instead of inserting it in YANG order
#
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/example.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

# feature f is deliberately NOT enabled via CLICON_FEATURE, so b1/b2 below
# are disabled and treated as anydata.
cat <<EOF > $fyang
module example {
  yang-version 1.1;
  namespace "urn:example:ex";
  prefix ex;

  feature f;

  container c {
    leaf a {
      type string;
    }
    leaf b1 {
      if-feature f;
      type string;
    }
    leaf b2 {
      if-feature f;
      type string;
    }
    list l {
      key k;
      leaf k {
        type string;
      }
      leaf v {
        type string;
      }
    }
  }
}
EOF

cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
  <c xmlns="urn:example:ex">
    <a>0</a>
    <b1>x</b1>
    <b2>y</b2>
    <l>
      <k>1</k>
      <v>old</v>
    </l>
  </c>
</${DATASTORE_TOP}>
EOF

new "test params: -f $cfg -s startup"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

# Step 1: merge the two disabled-feature (-> anydata) leaves b1/b2.
new "edit-config merge b1/b2 (anydata siblings)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>
       <c xmlns=\"urn:example:ex\">
         <b1>x</b1>
         <b2>y</b2>
       </c>
     </config></edit-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit step 1"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Primary assertion: sibling order must still be YANG order (a, b1, b2, l).
new "check sibling order preserved after anydata merge (core bug)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/ex:c\" xmlns:ex=\"urn:example:ex\"/></get-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:ex\"><a>0</a><b1>x</b1><b2>y</b2><l><k>1</k><v>old</v></l></c></data></rpc-reply>"

# Step 2: Merge an update into the existing list entry l[k=1].
new "edit-config merge existing list entry l[k=1]"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>
       <c xmlns=\"urn:example:ex\">
         <l>
           <k>1</k>
           <v>new</v>
         </l>
       </c>
     </config></edit-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "commit step 2"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><commit/></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Secondary assertion: exactly one l[k=1] entry, updated to v=new.
new "check no duplicate list entry after merging existing key (core bug, consequence)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/ex:c/ex:l\" xmlns:ex=\"urn:example:ex\"/></get-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:ex\"><l><k>1</k><v>new</v></l></c></data></rpc-reply>"

# Step 3: Copy to startup and restart.
new "copy running config to startup"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><copy-config><target><startup/></target><source><running/></source></copy-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

if [ $BE -ne 0 ]; then
    new "kill backend before restart"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
        err "kill backend"
    fi

    new "restart backend -s startup (must succeed; data-not-unique before fix)"
    start_backend -s startup -f $cfg
fi

new "wait backend after restart"
wait_backend

new "check single entry survives restart"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/ex:c/ex:l\" xmlns:ex=\"urn:example:ex\"/></get-config></rpc>" \
    "" "<rpc-reply $DEFAULTNS><data><c xmlns=\"urn:example:ex\"><l><k>1</k><v>new</v></l></c></data></rpc-reply>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
