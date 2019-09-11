#!/bin/bash
# Load startup with non-compatible and invalid module A with rev 0814-01-28
# Go into fail-safe with invalid startup
# Repair by copying startup into candidate, editing and commit it

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyangA0=$dir/A@0814-01-28.yang
fyangA1=$dir/A@2019-01-01.yang

OLDXML='<a0 xmlns="urn:example:a">old version</a0>'
SAMEXML='<a1 xmlns="urn:example:a">always work</a1>'
NEWXML='<a2 xmlns="urn:example:a">new version</a2>'

# Yang module A revision "0814-01-28"
# Note that this Yang model will exist in the DIR but will not be loaded
# by the system. Just here for reference
# XXX: Maybe it should be loaded and used in draft-wu?
cat <<EOF > $fyangA0
module A{
  prefix a;
  revision 0814-01-28;
  namespace "urn:example:a";
  leaf a0{
    type string;
  }
  leaf a1{
    type string;
  }
}
EOF

# Yang module A revision "2019-01-01"
cat <<EOF > $fyangA1
module A{
  prefix a;
  revision 2019-01-01;
  revision 0814-01-28;
  namespace "urn:example:a";
  /*  leaf a0 has been removed */
  leaf a1{
    description "exists in both versions";
    type string;
  } 
  leaf a2{
    description "has been added";
    type string;
  }
}
EOF

# Create configuration
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
</clixon-config>
EOF

# Create failsafe db
cat <<EOF > $dir/failsafe_db
<config>
   $SAMEXML
</config>
EOF

# Create non-compat startup db
# startup config XML with following (A obsolete, B OK, C lacking)
cat <<EOF > $dir/non-compat-invalid.xml
<config>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>0814-01-28</revision>
         <namespace>urn:example:a</namespace>
      </module>
   </modules-state>
   $OLDXML
   $SAMEXML
</config>
EOF

(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp non-compat-invalid.xml startup_db)

mode=startup

new "test params: -s $mode -f $cfg"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s $mode -f $cfg"
    start_backend -s $mode -f $cfg
fi

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

new "Check running db content is failsafe"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$SAMEXML</data></rpc-reply>]]>]]>$"

new "copy startup->candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><copy-config><target><candidate/></target><source><startup/></source></copy-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Check candidate db content is startup"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$OLDXML$SAMEXML</data></rpc-reply>]]>]]>$"

# Note you cannot edit invalid XML since a0 lacks namespace
new "Put new version into candidate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config operation='replace'>$NEWXML$SAMEXML</config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Check candidate db content is updated"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$SAMEXML$NEWXML</data></rpc-reply>]]>]]>$"

new "commit to running"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Check running db content is updated"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$SAMEXML$NEWXML</data></rpc-reply>]]>]]>$"

new "Kill restconf daemon"
stop_restconf

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u $BUSER -f clixon_backend)
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg

    rm -rf $dir
fi

