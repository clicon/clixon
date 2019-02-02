#!/bin/bash
# Choice type and mandatory
# Example from RFC7950 Sec 7.9.6
# Also test mandatory behaviour as in 7.6.5
# (XXX Would need default test in 7.6.4)
# Use-case: The ietf-netconf edit-config has a shorthand version of choice w mandatory:
# container { choice target { mandatory; leaf candidate; leaf running; }}

APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/choice.xml
fyang=$dir/type.yang

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>system</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
EOF

cat <<EOF > $fyang
module system{
  yang-version 1.1;
  namespace "urn:example:config";
  prefix ex;
  container system{
    /* From RFC 7950 7.9.6 */
    container protocol {
       presence true;
         choice name {
           case a {
             leaf udp {
               type empty;
             }
           }
           case b {
             leaf tcp {
               type empty;
             }
           }
         }
     }
    /* Same but shorthand */
    container shorthand {
       presence true;
         choice name {
             leaf udp {
               type empty;
             }
             leaf tcp {
               type empty;
             }
         }
     }
    /* Same with mandatory true */
    container mandatory {
       presence true;
         choice name {
           mandatory true;
           case a {
             leaf udp {
               type empty;
             }
           }
           case b {
             leaf tcp {
               type empty;
             }
           }
         }
     }
  }
}
EOF

new "test params: -f $cfg -y $fyang"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg -y $fyang"
    sudo $clixon_backend -s init -f $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
sudo su -c "$clixon_restconf -f $cfg -y $fyang -D $DBG" -s /bin/sh www-data &

# First vanilla (protocol) case
new "netconf validate empty"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf set empty protocol"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><protocol/></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate protocol"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf set protocol tcp"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><protocol><tcp/></protocol></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get protocol tcp"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><system xmlns="urn:example:config"><protocol><tcp/></protocol></system></data></rpc-reply>]]>]]>$'

new "netconf commit protocol tcp"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf changing from TCP to UDP (RFC7950 7.9.6)"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><protocol><udp nc:operation="create"/></protocol></system></config></edit-config></rpc>]]>]]>' '^<rpc-reply message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"><ok/></rpc-reply>]]>]]>$'

new "netconf get protocol udp"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><system xmlns="urn:example:config"><protocol><udp/></protocol></system></data></rpc-reply>]]>]]>$'

new "netconf commit protocol udp"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "restconf set protocol tcp"
expecteq "$(curl -s -X PUT http://localhost/restconf/data/system:system/protocol -d {\"system:protocol\":{\"tcp\":null}})" ""

new "restconf get protocol tcp"
expecteq "$(curl -s -X GET http://localhost/restconf/data/system:system)" '{"system:system": {"protocol": {"tcp": null}}}
'

new "cli set protocol udp"
expectfn "$clixon_cli -1 -f $cfg -y $fyang -l o set system protocol udp" 0 "^$"

new "cli get protocol udp"
expectfn "$clixon_cli -1 -f $cfg -y $fyang -l o show configuration cli " 0 "^system protocol udp$"

new "cli delete all"
expectfn "$clixon_cli -1 -f $cfg -y $fyang -l o delete all" 0 "^$"

new "commit"
expectfn "$clixon_cli -1 -f $cfg -y $fyang -l o commit" 0 "^$"

# Second shorthand (no case)
new "netconf set shorthand tcp"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><shorthand><tcp/></shorthand></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf changing from TCP to UDP (RFC7950 7.9.6)"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><shorthand><udp/></shorthand></system></config></edit-config></rpc>]]>]]>' '^<rpc-reply message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"><ok/></rpc-reply>]]>]]>$'

new "netconf get shorthand udp"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><system xmlns="urn:example:config"><shorthand><udp/></shorthand></system></data></rpc-reply>]]>]]>$'

new "netconf validate shorthand"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Third check mandatory
new "netconf set empty mandatory"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><mandatory/></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get mandatory empty"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><system xmlns="urn:example:config"><mandatory/></system></data></rpc-reply>]]>]]>$'

new "netconf validate mandatory"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>missing-choice</error-app-tag><error-info><missing-choice>name</missing-choice></error-info><error-severity>error</error-severity></rpc-error></rpc-reply>]]>]]>$'

new "netconf set mandatory udp"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><mandatory><udp/></mandatory></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get mandatory udp"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><system xmlns="urn:example:config"><mandatory><udp/></mandatory></system></data></rpc-reply>]]>]]>$'

new "netconf validate mandatory"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Kill restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
sudo clixon_backend -z -f $cfg
if [ $? -ne 0 ]; then
    err "kill backend"
fi

rm -rf $dir
