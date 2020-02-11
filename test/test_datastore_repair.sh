#!/usr/bin/env bash
# Keep a vector of {xpath, namespace} pairs, match xpath in parsed XML and check if symbols belong to namespace
# If not, set that namespace.
# This is a primitive upgrade mechanism if th emore general upgrade mechanism can not be used

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

# Yang module A (base)
cat <<EOF > $fyangA
module A{
  prefix a;
  revision 2020-02-11;
  namespace "urn:example:a";
  container x {
    container y {
    }
  }
}
EOF

# Yang module B (augments A)
cat <<EOF > $fyangB
module B{
  prefix b;
  revision 2020-02-11;
  namespace "urn:example:b";
  import A {
     prefix "a";
  }
  augment "/a:x/ngrt:y" {
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
# Create startup db of "old" db with incorrect augment namespace tagging
cat <<EOF > $dir/startup_db
<config>
   <x xmlns="urn:example:a">
     <y>
        <z>
          <w>foo</w>
        </z>
     </y>
   </x>
</config>
EOF

# This is how it should look after repair, using prefixes
AFTER=$(cat <<EOF
<x xmlns="urn:example:a"><y><b:z xmlns:b="urn:example:b"><b:w>foo</b:w></b:z></y></x>
EOF
)

# Or using default:
# <config><x xmlns="urn:example:a"><y><z xmlns="urn:example:b"><w>foo</w></z></y></x></config>

new "test params: -f $cfg"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg

    new "waiting"
    wait_backend
fi

new "netconf get config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data>$AFTER</data></rpc-reply>]]>]]>$"

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

#rm -rf $dir
