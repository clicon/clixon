#!/bin/bash
# Authentication and authorization

# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang
fyangerr=$dir/err.yang

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/routing/yang</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>example</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/routing/clispec</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/routing/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/routing/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>routing</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/routing/routing.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/routing/routing.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/routing</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
</config>
EOF

cat <<EOF > $fyang
module example{
  prefix ex;
  leaf basic_auth{
	description "Basic user / password authentication as in HTTP basic auth";
	type boolean;
	default false;
  }
  list auth {
	description "user / password entries. Valid if basic_auth=true";
	key user;
	leaf user{
	    description "User name";
	    type string;
	}
	leaf password{
	    description "Password";
	    type string;
	}
    }
}
EOF

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg -y $fyang
if [ $? -ne 0 ]; then
    err
fi

new "start backend -s init -f $cfg -y $fyang"
# start new backend
sudo clixon_backend -s init -f $cfg -y $fyang
if [ $? -ne 0 ]; then
    err
fi

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
sudo start-stop-daemon -S -q -o -b -x /www-data/clixon_restconf -d /www-data -c www-data -- -f $cfg # -D

sleep 1

new2 "auth get"
expecteq "$(curl -sS -X GET http://localhost/restconf/data)" '{"data": null}
'

new "auth set authentication config"
expecteof "$clixon_netconf -qf $cfg -y $fyang" "<rpc><edit-config><target><candidate/></target><config><basic_auth>true</basic_auth><auth><user>foo</user><password>bar</password></auth></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

expecteof "$clixon_netconf -qf $cfg -y $fyang" "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new2 "auth get (access denied)"
expecteq "$(curl -sS -X GET http://localhost/restconf/data)" "<error-tag>access-denied</error-tag>
The requested URL /restconf/data was unauthorized."

new2 "auth get (access)"
expecteq "$(curl -u foo:bar -sS -X GET http://localhost/restconf/data)" '{"data": {"basic_auth": true,"auth": [{"user": "foo","password": "bar"}]}}
'

new "Kill restconf daemon"
sudo pkill -u www-data clixon_restconf

pid=`pgrep clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
