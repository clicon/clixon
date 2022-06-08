#!/usr/bin/env bash
# Test of the general-purpose (raw) upgrade mechanism.
# Input is a startup db without mod-state info.
# It has wrong namespace bindings and needs to remove some nodes
# Output is a valid config with correct namespaces and removed nods
# The code for this is in the main example backend plugin.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyangA=$dir/A.yang
fyangB=$dir/B.yang

# Create configuration
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <CLICON_XMLDB_UPGRADE_CHECKOLD>false</CLICON_XMLDB_UPGRADE_CHECKOLD>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
</clixon-config>
EOF

# Yang module A (base)
cat <<EOF > $fyangA
module A{
  prefix a;
  namespace "urn:example:a";
  revision 2020-02-11;
  container x {
    container y {
    }
  }
  list remove_me {
    key k;
    leaf k {
      type string;
    }
  }
}
EOF

# Yang module B (augments A)
cat <<EOF > $fyangB
module B{
  prefix b;
  namespace "urn:example:b";
  import A {
     prefix "a";
  }
  revision 2020-02-11;
  augment "/a:x/a:y" {
    container z {
      leaf w {
        type string;
      }
    }
  }
}
EOF

# permission kludges
sudo touch $dir/startup_db
sudo chmod 666 $dir/startup_db

# This is how it should look after repair, using prefixes
AFTER=$(cat <<EOF
<x xmlns="urn:example:a"><y><z xmlns="urn:example:b"><w>foo</w></z></y></x>
EOF
)

function testrun(){
    new "test params: -f $cfg -- -U" # -U : upgrade
    # Bring your own backend
    if [ $BE -ne 0 ]; then
	# kill old backend (if any)
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s startup -f $cfg -- -U"
	start_backend -s startup -f $cfg -- -U
    fi

    new "wait backend"
    wait_backend
    
    new "netconf get config"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data>$AFTER</data></rpc-reply>"

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

} # end testrun

# Create startup db of "old" db with incorrect augment namespace tagging
# without modstate
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
   <x xmlns="urn:example:a">
     <y>
        <z>
          <w>foo</w>
        </z>
     </y>
   </x>
   <remove_me xmlns="urn:example:a"><k>This node is obsolete</k></remove_me>
   <remove_me xmlns="urn:example:a"><k>this too</k></remove_me>
</${DATASTORE_TOP}>
EOF

new "general-purpose upgrade without modstate"
testrun

rm -rf $dir

new "endtest"
endtest
