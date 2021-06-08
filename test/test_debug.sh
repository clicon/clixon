#!/usr/bin/env bash
# Turn on debug on backend/cli/restconf/netconf

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
fyang=$dir/restconf.yang

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

#  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$dir/restconf.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  $RESTCONFIG
</clixon-config>nn
EOF

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
    /* Generic config data */
    container table{
	list parameter{
	    key name;
	    leaf name{
		type string;
	    }
	    leaf value{
		type string;
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
    sudo pkill -f clixon_backend # to be sure
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
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

new "Set backend debug using netconf"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><debug $LIBNS><level>1</level></debug></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Set backend debug using restconf"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/operations/clixon-lib:debug -d '{"clixon-lib:input":{"level":1}}')" 0 "HTTP/$HVER 204"

new "Set restconf debug using netconf"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><restconf $RESTCONFNS><debug>1</debug></restconf></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Set restconf debug using restconf"
expectpart "$(curl $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+json' $RCPROTO://localhost/restconf/data/clixon-restconf:restconf/debug -d '{"clixon-restconf:debug":1}')" 0 "HTTP/$HVER 204"

new "Set cli debug using cli"
expectpart "$($clixon_cli -1 -f $cfg -l o debug cli 1)" 0 "^$"

new "Set backend debug using cli"
expectpart "$($clixon_cli -1 -f $cfg -l o debug backend 1)" 0 "^$"

new "Set restconf debug using cli"
expectpart "$($clixon_cli -1 -f $cfg -l o debug restconf 1)" 0 "^$"

# Exercise debug code
new "get and put config using restconf"
expectpart "$(curl $CURLOPTS -H "Accept: application/yang-data+xml" -X GET $RCPROTO://localhost/restconf/data?content=config --next $CURLOPTS -H "Content-Type: application/yang-data+json" -X POST $RCPROTO://localhost/restconf/data -d '{"example:table":{"parameter":{"name":"local0","value":"foo"}}}')" 0 "HTTP/$HVER 200" '<data>' "HTTP/$HVER 201"

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
fi

# Set by restconf_config
unset RESTCONFIG

rm -rf $dir

new "endtest"
endtest
