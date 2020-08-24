#!/usr/bin/env bash
# Clixon leaf default test
# Check top-level default as https://github.com/clicon/clixon/issues/111
# Also check
# Sanity check default value may not be in list key
# RFC 7950:
# 7.6.1 The usage of the default value depends on the leaf's closest ancestor node in the
#       schema tree that is not a non-presence container (see Section 7.5.1):
# 7.8.2 any default values in the key leafs or their types are ignored.
#             v non-presence container (presence false) DEFAULT
# ancestor--> ancestor --> leaf --> default
# ^leafs closest ancestor that is not a non-presence container

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/leafref.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example{
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    leaf r1 { 
      description "Top level leaf";	
        type uint32; 
        default 11;  /* should be set */
    }
    leaf r2 { 
      description "Top level leaf";	
        type uint32; 
        default 22;  /* should be set on startup */
    }
    container np3{
      description "No presence container";
      leaf s3 {
        type uint32;
        default 33;  /* should be set on startup */
      } 
      container np31{
        leaf s31 {
          type uint32;
          default 31;  /* should be set on startup */
        } 
      }
    }
    container p4{
      presence "A presence container";
      description "Not a no presence container";
      leaf s4 {
        type uint32;
        default 44; 
      } 
      container np45{
        description "No presence container";	
	leaf s5 {
          type uint32;
          default 45; 
        }   
      }
    }
}
EOF

# This is base default XML with all default values from root filled in
XML='<r1 xmlns="urn:example:clixon">11</r1><r2 xmlns="urn:example:clixon">22</r2><np3 xmlns="urn:example:clixon"><s3>33</s3><np31><s31>31</s31></np31></np3>'

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s init -f $cfg"
    start_backend -s init -f $cfg

    new "waiting"
    wait_backend
fi

new "get config"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$XML</data></rpc-reply>]]>]]>$"

new "Change default value r1"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><r1 xmlns="urn:example:clixon">99</r1></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "get config r1"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source><filter type=\"xpath\" select=\"/ex:r1\" xmlns:ex=\"urn:example:clixon\" /></get-config></rpc>]]>]]>" '^<rpc-reply><data><r1 xmlns="urn:example:clixon">99</r1></data></rpc-reply>]]>]]>$'

new "Remove r1"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><r1 xmlns="urn:example:clixon" nc:operation="delete" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0">99</r1></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "get config"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$XML</data></rpc-reply>]]>]]>$"

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

# From startup 1, only r1, all else should be filled in
SXML='<r1 xmlns="urn:example:clixon">99</r1>'
cat <<EOF > $dir/startup_db
<config>
  $SXML
</config>
EOF
XML='<r1 xmlns="urn:example:clixon">99</r1><r2 xmlns="urn:example:clixon">22</r2><np3 xmlns="urn:example:clixon"><s3>33</s3><np31><s31>31</s31></np31></np3>'

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s startup -f $cfg"
    start_backend -s startup -f $cfg

    new "waiting"
    wait_backend
fi

new "get startup config"
# Should have all defaults, except r1 that is set to 99
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$XML</data></rpc-reply>]]>]]>$"

# permission kludges
sudo chmod 666 $dir/running_db
new "Check running no defaults: r1 only"
# Running should have only non-defaults, ie only r1 that is set to 99

moreret=$(diff $dir/running_db <(echo "<config>
   $SXML
</config>"))
if [ $? -ne 0 ]; then
    err "<config>$SXML</config>" "$moreret"
fi	

new "Change default value r2"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><r2 xmlns="urn:example:clixon">88</r2></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "commit"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><commit/></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Check running no defaults: r1 and r2"
# Again, running should have only non-defaults, ie only r1 and r2
moreret=$(diff $dir/running_db <(echo "<config>
   $SXML
   <r2 xmlns=\"urn:example:clixon\">88</r2>
</config>"))
if [ $? -ne 0 ]; then
    err "<config>$SXML<r2 xmlns=\"urn:example:clixon\">88</r2></config>" "$moreret"
fi	

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi

# From startup 2, only prsence p4, s4/np5 should be filled in
cat <<EOF > $dir/startup_db
<config>
  <p4 xmlns="urn:example:clixon"></p4>
</config>
EOF
XML='<r1 xmlns="urn:example:clixon">11</r1><r2 xmlns="urn:example:clixon">22</r2><np3 xmlns="urn:example:clixon"><s3>33</s3><np31><s31>31</s31></np31></np3><p4 xmlns="urn:example:clixon"><s4>44</s4><np45><s5>45</s5></np45></p4>'
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s startup -f $cfg"
    start_backend -s startup -f $cfg

    new "waiting"
    wait_backend
fi

new "get startup config with presence"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$XML</data></rpc-reply>]]>]]>$"

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi

rm -rf $dir
