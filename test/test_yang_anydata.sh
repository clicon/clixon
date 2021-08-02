#!/usr/bin/env bash
# Test YANG ANYDATA:
# Also Test CLICON_YANG_UNKNOWN_ANYDATA: Treat unknown XML/JSON nodes as anydata. 
# Test matrix is three dimensions:
# 1. YANG spec:  Add elements denotend with "u" which are either a) defined as anydata or b) unknown
# 2. Make access to elements as: a) top-level, b) in container, c) in list
# 3. data is in a) startup b) netconf 3) state

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

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

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
   rpc myrpc {
	input {
	    anydata u7;
	}
	output {
	    anydata u8;
	}
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
   rpc myrpc {
   }
}
EOF

# For edit config
XMLA='<ca xmlns="urn:example:any"><b><k>22</k><u3><u31>42</u31></u3></b><u2><u21>a string</u21></u2></ca><u1 xmlns="urn:example:any"><u11>23</u11></u1>'

XMLU='<cu xmlns="urn:example:unknown"><b><k>22</k><u3><u31>42</u31></u3></b><u2><u21>a string</u21></u2></cu><u1 xmlns="urn:example:unknown"><u11>23</u11></u1>'

# Full state with unknowns
STATE0='<sa xmlns="urn:example:any"><sb><k>22</k><u5>55</u5></sb><u4><u5>a string</u5></u4></sa><su xmlns="urn:example:unknown"><sb><k>22</k><u5>55</u5></sb><u4><u5>a string</u5></u4></su>'

# Partial state with unknowns removed in the unknown module
STATE1='<sa xmlns="urn:example:any"><sb><k>22</k><u5>55</u5></sb><u4><u5>a string</u5></u4></sa><su xmlns="urn:example:unknown"><sb><k>22</k></sb></su>'

# Run anydata and unknown tests
# From a startup db or via netconf commands as well as state data
# Test both anydata and unknown
# Args:
# 1: bool: startup (or not)
# 2: bool: treat unknown as anydata (or not)
function testrun()
{
    startup=$1
    unknown=$2

    if $unknown; then # treat unknown as anydata or not
	if $startup; then # If startup
	    XML="$XMLA$XMLU"
	else
	    XML="$XMLA"
	    unknownreply="<rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>u3</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: u3 with parent: b in namespace: urn:example:unknown</error-message></rpc-error>"
	fi
    else
	XML="$XMLA"
	unknownreply="<rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>u3</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: u3 with parent: b in namespace: urn:example:unknown</error-message></rpc-error>"
    fi

    if $startup; then # get config from startup
	F="<CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>"
    else
	F=""
    fi
    cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
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
  $RESTCONFIG
</clixon-config>
EOF

    if $startup; then
	# Only positive startup test, ie dont add XMLU if unknown not treated as anyxml
	# and check for errors
	cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>    
  $XML
</${DATASTORE_TOP}>
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
    fi
    new "wait backend"
    wait_backend

    if [ $RC -ne 0 ]; then
	new "kill old restconf daemon"
	stop_restconf_pre

	new "start restconf daemon"
	start_restconf -f $cfg

    fi
    new "wait restconf"
    wait_restconf

    if ! $startup; then # If not startup, add xml using netconf
	new "Put anydata"
	expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$XMLA</config></edit-config></rpc>]]>]]>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

	new "Put unknown"
	expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$XMLU</config></edit-config></rpc>]]>]]>" "$unknownreply"

	new "commit"
	expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"
    fi
    
    new "Get candidate"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data>$XML</data></rpc-reply>]]>]]>$"

    new "Get running"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data>$XML</data></rpc-reply>]]>]]>$"

    # Add other functions, (based on previous errors), eg cli show config, cli commit.
    new "cli show configuration"
    expectpart "$($clixon_cli -1 -f $cfg show conf xml)" 0 "<u31>42</u31>"

    new "cli commit"
    expectpart "$($clixon_cli -1 -f $cfg commit)" 0 "^$"

    new "restconf get config"
    expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data?content=config)" 0 "HTTP/$HVER 200" "$XML"

    new "Save partial state with unknowns removed in state file $fstate"
    echo "$STATE1" > $fstate 

    new "Get state (positive test)"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get content=\"nonconfig\"></get></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data>$STATE1</data></rpc-reply>]]>]]>"

    new "restconf get state(positive)"
    expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data?content=nonconfig)" 0 "HTTP/$HVER 200" "$STATE1"

    new "Save full state with unknowns in state file $fstate"
    echo "$STATE0" > $fstate 

    new "Get state (negative test)"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get content=\"nonconfig\"></get></rpc>]]>]]>" "error-message>Failed to find YANG spec of XML node: u5 with parent: sb in namespace: urn:example:unknown. Internal error, state callback returned invalid XML from plugin: example_backend</error-message>"

	new "restconf get state(negative)"
    expectpart "$(curl $CURLOPTS -X GET -H "Accept: application/yang-data+xml" $RCPROTO://localhost/restconf/data?content=nonconfig)" 0 "HTTP/$HVER 412" "<error-tag>operation-failed</error-tag><error-info><bad-element>u5</bad-element></error-info>"

    # RPC:s take "not-supported" as OK: syntax OK and according to mdeol, just not implemented in
    # server. But "unknown-element" as truly unknwon.
    # (Would need to add a handler to get a proper OK)
    new "Not supported RPC"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><myrpc xmlns=\"urn:example:any\"></myrpc></rpc>]]>]]>" "<error-tag>operation-not-supported</error-tag>"

    new "anydata RPC"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><myrpc xmlns=\"urn:example:any\"><u7><u8>88</u8></u7></myrpc></rpc>]]>]]>" "<error-tag>operation-not-supported</error-tag>"

    new "unknown RPC"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><myrpc xmlns=\"urn:example:unknown\"><u7><u8>88</u8></u7></myrpc></rpc>]]>]]>" "<error-tag>unknown-element</error-tag>"

    if [ $RC -ne 0 ]; then
	new "Kill restconf daemon"
	stop_restconf
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

new "1. no startup, dont treat unknown as anydata----"
testrun false false

new "2. startup, dont treat unknown as anydata----"
testrun true false

new "3. no startup, treat unknown as anydata----"
testrun false true

new "4. startup, treat unknown as anydata----"
testrun true true

# Set by restconf_config
unset RESTCONFIG

rm -rf $dir

new "endtest"
endtest
