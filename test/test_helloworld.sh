#!/usr/bin/env bash
# Hello world smoketest test
# A minimal test for backend/cli/netconf/restconf
# See clixon-example/hello
# but this test is (more or less) self-contained for as little external dependencies as possible
# The test is free of plugins because that would require compilation, or pre-built plugins
# Restconf is internal native http port 80
# The minimality extends to the test macros that use advanced grep, and therefore more
# primitive pattern macthing is made

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

cfg=$dir/hello.xml
fyang=$dir/clixon-hello.yang
clispec=$dir/clispec
test -d $clispec || mkdir $clispec

RCPROTO=http

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>	
  <CLICON_CLISPEC_DIR>$clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_MODE>hello</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/hello.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/var/run/helloworld.pid</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_STARTUP_MODE>init</CLICON_STARTUP_MODE>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_SOCK_GROUP>clicon</CLICON_SOCK_GROUP>
  <CLICON_RESTCONF_USER>www-data</CLICON_RESTCONF_USER>
  <CLICON_RESTCONF_PRIVILEGES>drop_perm</CLICON_RESTCONF_PRIVILEGES>
  <CLICON_RESTCONF_HTTP2_PLAIN>true</CLICON_RESTCONF_HTTP2_PLAIN>
  <restconf>
      <enable>true</enable>
      <auth-type>none</auth-type>
      <pretty>false</pretty>
      <debug>0</debug>
      <log-destination>file</log-destination>
      <socket>
         <namespace>default</namespace>
	 <address>0.0.0.0</address>
	 <port>80</port>
	 <ssl>false</ssl>
      </socket>
   </restconf>
  <autocli>
    <module-default>false</module-default>
     <rule>
        <name>include hello yang</name>
        <operation>enable</operation>
        <module-name>clixon-hello*</module-name>
     </rule>
  </autocli>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-hello {
    yang-version 1.1;
    namespace "urn:example:hello";
    prefix he;
    revision 2019-04-17 {
	description
	    "Clixon hello world example";
    }
    container hello{
	container world{
	    presence true;
	}
    }
}
EOF

# XXX remove unecessary commands
cat <<EOF > $clispec/hello_cli.cli
CLICON_MODE="hello";
CLICON_PROMPT="cli> ";

# Reference generated data model
set @datamodel, cli_set();
merge @datamodel, cli_merge();
create @datamodel, cli_create();
delete("Delete a configuration item") @datamodel, cli_del();
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
show("Show a particular state of the system")
    configuration("Show configuration"), cli_show_config("candidate", "text", "/");

EOF

new "test params: -f $cfg"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s init -f $cfg"
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

new "cli configure"
#expectpart "$($clixon_cli -1 -f $cfg set hello world)" 0 "^$"
ret=$($clixon_cli -1 -f $cfg set hello world)
if [ $? -ne 0 ]; then
    err 0 $r
fi

new "cli show config"
ret=$($clixon_cli -1 -f $cfg show config)
if [ $? -ne 0 ]; then
    err 0 $r
fi  
if [ "$ret" != "clixon-hello:hello     world;" ]; then
    err "$ret" "clixon-hello:hello     world;"
fi

new "netconf edit-config"
rpc=$(chunked_framing "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><hello xmlns=\"urn:example:hello\"><world/></hello></config></edit-config></rpc>")
ret=$(echo "$DEFAULTHELLO$rpc" | $clixon_netconf -qf $cfg)
if [ $? -ne 0 ]; then
    err 0 $r
fi
reply=$(chunked_framing "<rpc-reply $DEFAULTNS><ok/></rpc-reply>")
if [ "$ret" != "$reply" ]; then
    err "$ret" "$reply"
fi

new "netconf commit"
rpc=$(chunked_framing "<rpc $DEFAULTNS><commit/></rpc>")
ret=$(echo "$DEFAULTHELLO$rpc" | $clixon_netconf -qf $cfg)
if [ $? -ne 0 ]; then
    err 0 $r
fi
if [ "$ret" != "$reply" ]; then
    err "$ret" "$reply"
fi

new "restconf GET"
ret=$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-hello:hello)
if [ $? -ne 0 ]; then
    err 0 $r
fi

res=$(echo "$ret"|grep "HTTP/$HVER 200")
if [ -z "$res" ]; then
    err "$ret" "HTTP/$HVER 200"
fi

res=$(echo "$ret"|grep '{"clixon-hello:hello":{"world":{}}}')
if [ -z "$res" ]; then
    err "$ret" "{"clixon-hello:hello":{"world":{}}}"
fi

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf 
fi

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -f clixon_backend)
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
fi

rm -rf $dir

RCPROTO=  # This is sh not bash undef

new "endtest"
endtest
