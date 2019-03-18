#!/bin/bash
# Start clixon with module A rec 2019
# Load startup with non-compatible and invalid module A with rev 0814-01-28
# Go into fail-safe with invalid startup

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyangA0=$dir/A@0814-01-28.yang
fyangA1=$dir/A@2019-01-01.yang

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
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
</clixon-config>
EOF

# Create failsafe db
cat <<EOF > $dir/failsafe_db
<config>
   <a1 xmlns="urn:example:a">always work</a1>
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
   <a0 xmlns="urn:example:a">old version</a0>
   <a1 xmlns="urn:example:a">always work</a1>
</config>
EOF

(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp non-compat-invalid.xml startup_db)

mode=startup

new "test params: -f $cfg"
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
new "waiting"
sleep $RCWAIT

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
sleep $RCWAIT

new "Check running db content is failsafe"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' '^<rpc-reply><data><a1 xmlns="urn:example:a">always work</a1></data></rpc-reply>]]>]]>$'

#repair    

#exit

new "Kill restconf daemon"
stop_restconf

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=`pgrep -u root -f clixon_backend`
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg

    rm -rf $dir
fi

