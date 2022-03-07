#!/usr/bin/env bash
# Tests for openconfig network-instances
# See eg https://github.com/clicon/clixon/issues/287

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/clixon-example.yang

new "openconfig"
if [ ! -d "$OPENCONFIG" ]; then
#    err "Hmm Openconfig dir does not seem to exist, try git clone https://github.com/openconfig/public?"
    echo "...skipped: OPENCONFIG not set"
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

OCDIR=$OPENCONFIG/release/models

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$OCDIR</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>	
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <autocli>
     <module-default>false</module-default>
     <list-keyword-default>kw-nokey</list-keyword-default>
     <treeref-state-default>false</treeref-state-default>
     <rule>
       <name>openconfig1</name>
       <operation>enable</operation>
       <module-name>clixon-example</module-name>
     </rule>
     <rule>
       <name>openconfig2</name>
       <operation>enable</operation>
       <module-name>openconfig-network-instance</module-name>
     </rule>
  </autocli>
</clixon-config>
EOF

# First using ietf-interfaces (not openconfig-interfaces)
# Example yang
cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:example";
  prefix ex;

  import openconfig-network-instance {
    prefix oc-netinst;
  }
}
EOF

# Example system
cat <<EOF > $dir/startup_db
<config>
  <network-instances xmlns="http://openconfig.net/yang/network-instance">
    <network-instance>
      <name>default</name>
      <fdb>
         <config>
            <flood-unknown-unicast-supression>false</flood-unknown-unicast-supression>
         </config>
      </fdb>
      <config>
         <name>default</name>
         <type>oc-ni-types:DEFAULT_INSTANCE</type>
         <enabled>true</enabled>
         <router-id>1.2.3.4</router-id>
      </config>
    </network-instance>
  </network-instances>
</config>
EOF

cat<<EOF > $dir/example_cli.cli
# Clixon example specification
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

set @datamodel, cli_auto_set();
save("Save candidate configuration to XML file") <filename:string>("Filename (local filename)"), save_config_file("candidate","filename", "xml");{
    cli("Save configuration as CLI commands"), save_config_file("candidate","filename", "cli");
}
show("Show a particular state of the system"){
    configuration("Show configuration"), cli_auto_show("datamodel", "candidate", "xml", false, false);
    version("Show version"), cli_show_version("candidate", "text", "/");
}
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
EOF

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    sudo pkill -f clixon_backend # to be sure
    
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

new "$clixon_cli -D $DBG -1f $cfg show version"
expectpart "$($clixon_cli -D $DBG -1f $cfg show version)" 0 "${CLIXON_VERSION}"

new "$clixon_cli -D $DBG -1f $cfg save config as cli"
expectpart "$($clixon_cli -D $DBG -1f $cfg save $dir/config.dump cli)" 0 "^$"

new "Check saved config"
expectpart "$(cat $dir/config.dump)" 0 "set network-instances network-instance default config type oc-ni-types:DEFAULT_INSTANCE" "set network-instances network-instance default config router-id 1.2.3.4"

new "load saved cli config"
expectpart "$(cat $dir/config.dump | $clixon_cli -D $DBG -f $cfg 2>&1 > /dev/null)" 0 "^$"

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
