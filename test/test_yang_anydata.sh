#!/usr/bin/env bash
# Test YANG ANYDATA:
# Also Test CLICON_YANG_UNKNOWN_ANYDATA: Treat unknown XML/JSON nodes as anydata. 
# Test matric is three dimensions:
# 1. YANG spec:  u-elements are a) anydata or b) unknown
# 2. Access is made to top-elements: a) top-level, b) in container, c) in list
# 3. data is in a) startup b) netconf 3)state

# Load an XML file with unknown yang constructs that is labelled as anydata
# Ensure clixon is robust to handle that
# Test is that unknown XML subcomponents (with label u) are loaded in an xml file.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

test -d $dir/yang || mkdir $dir/yang
cfg=$dir/conf_yang.xml
fanydata=$dir/yang/anydata.yang
funknown=$dir/yang/unknown.yang 
fstate=$dir/state.xml

cat <<EOF > $fanydata
module any{
   yang-version 1.1;
   prefix any;
   namespace "urn:example:any";
   container ca{
     list b{
       key k;
       leaf k {
         type string;
       }
       anydata u3;
     }
     anydata u2;
   }
   anydata u1;
   container sa{
     config false;
     list sb{
       key k;
       leaf k {
         type string;
       }
       anydata u5;
     }
     anydata u4;
   }
}
EOF

cat <<EOF > $funknown
module unknown{
   yang-version 1.1;
   prefix un;
   namespace "urn:example:unknown";
   container cu{
     list b{
       key k;
       leaf k {
         type string;
       }
     }
   }
   container su{
     config false;
     list sb{
       key k;
       leaf k {
         type string;
       }
     }
   }
}
EOF

# For edit config
XMLA='<ca xmlns="urn:example:any"><b><k>22</k><u3><u31>42</u31></u3></b><u2><u21>a string</u21></u2></ca><u1 xmlns="urn:example:any"><u11>23</u11></u1>'

XMLU='<cu xmlns="urn:example:unknown"><b><k>22</k><u3><u31>42</u31></u3></b><u2><u21>a string</u21></u2></cu><u1 xmlns="urn:example:unknown"><u11>23</u11></u1>'

# Full state
STATE0='<sa xmlns="urn:example:any"><sb><k>22</k><u5>55</u5></sb><u4><u5>a string</u5></u4></sa><su xmlns="urn:example:unknown"><sb><k>22</k><u5>55</u5></sb><u4><u5>a string</u5></u4></su>'

# Partial state with unknowns removed in the unknown module
STATE1='<sa xmlns="urn:example:any"><sb><k>22</k><u5>55</u5></sb><u4><u5>a string</u5></u4></sa><su xmlns="urn:example:unknown"><sb><k>22</k></sb></su>'

# Run anydata and unknown tests
# From a startup db or via netconf commands as well as state data
# Test both anydata and unknown
# Args:
# 1: bool: startup (or not)
# 2: bool: treat unknown as anydata (or not)
testrun()
{
    startup=$1
    unknown=$2

    if $unknown; then # treat unknown as anydata or not
	unknownreply="<rpc-reply><ok/></rpc-reply>]]>]]>"
	XML="$XMLA$XMLU"
    else
	unknownreply="<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>u1</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>"
	XML="$XMLA"
    fi

    if $startup; then # get config from startup
	F="<CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>"
    else
	F=""
    fi
    cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir/yang</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_YANG_UNKNOWN_ANYDATA>$unknown</CLICON_YANG_UNKNOWN_ANYDATA>
  $F
</clixon-config>
EOF

    if $startup; then
	# Only positive startup test, ie dont add XMLU if unknown not treated as anyxml
	# and check for errors
	cat <<EOF > $dir/startup_db
<config>    
  $XML
</config>
EOF
    fi

    if [ $BE -ne 0 ]; then
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	if $startup; then
	    new "start backend -s startup -f $cfg -- -sS $fstate"
	    start_backend -s startup -f $cfg -- -sS $fstate
	else
	    new "start backend -s init -f $cfg -- -sS $fstate"
	    start_backend -s init -f $cfg -- -sS $fstate
	fi

	new "waiting"
	wait_backend
    fi


    if ! $startup; then # If not startup, add xml using netconf
	new "Put anydata"
	expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "<rpc><edit-config><target><candidate/></target><config>$XMLA</config></edit-config></rpc>]]>]]>" "<rpc-reply><ok/></rpc-reply>]]>]]>"

	new "Put unknown"
	expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "<rpc><edit-config><target><candidate/></target><config>$XMLU</config></edit-config></rpc>]]>]]>" "$unknownreply"

	new "commit"
	expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "<rpc><commit/></rpc>]]>]]>" "<rpc-reply><ok/></rpc-reply>]]>]]>"
    fi
    
    new "Get candidate"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$XML</data></rpc-reply>]]>]]>$"

    new "Get running"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$XML</data></rpc-reply>]]>]]>$"

    # Add other functions, (based on previous errors), eg cli show config, cli commit.
    new "cli show configuration"
    expectpart "$($clixon_cli -1 -f $cfg show conf xml)" 0 "<u31>42</u31>"

    new "cli commit"
    expectpart "$($clixon_cli -1 -f $cfg commit)" 0 "^$"

    if $unknown; then
	STATE="$STATE0" # full state
    else
	STATE="$STATE1" # partial state
    fi
    echo "$STATE" > $fstate 

    new "Get state (positive test)"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="nonconfig"></get></rpc>]]>]]>' "^<rpc-reply><data>$STATE</data></rpc-reply>]]>]]>"

    echo "$STATE0" > $fstate # full state

    new "Get state (negative test)"
    if $unknown; then
	expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="nonconfig"></get></rpc>]]>]]>' "^<rpc-reply><data>$STATE</data></rpc-reply>]]>]]>"
    else
	expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get content="nonconfig"></get></rpc>]]>]]>' "error-message>Failed to find YANG spec of XML node: u5 with parent: sb in namespace: urn:example:unknown. Internal error, state callback returned invalid XML: example_backend</error-message>"
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
}

new "test params: -f $cfg"

new "no startup, dont treat unknown as anydata"
testrun false false

new "startup, dont treat unknown as anydata"
testrun true false

new "no startup, treat unknown as anydata"
testrun false true

new "startup, treat unknown as anydata"
testrun true true

rm -rf $dir
