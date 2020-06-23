#!/usr/bin/env bash
# Choice type and mandatory
# Example from RFC7950 Sec 7.9.6
# Also test mandatory behaviour as in 7.6.5
# (XXX Would need default test in 7.6.4)
# Use-case: The ietf-netconf edit-config has a shorthand version of choice w mandatory:
# container { choice target { mandatory; leaf candidate; leaf running; }}

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/choice.xml
fyang=$dir/type.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
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
    /* Choice with multiple items */
    choice mch {
      case first{
        leaf-list ma {
          type int32;
        }
        leaf mb {
          type int32;
        }
      }
      case second{
        leaf-list mc {
          type int32;
        }
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

new "waiting"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg

    new "waiting"
    wait_restconf
fi

# First vanilla (protocol) case
new "netconf validate empty"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf set protocol both udp and tcp"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><protocol><tcp/><udp/></protocol></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate both udp and tcp fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>udp</bad-element></error-info><error-severity>error</error-severity><error-message>Element in choice statement already exists</error-message></rpc-error></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf set empty protocol"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><protocol/></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate protocol"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf set protocol tcp"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><protocol><tcp/></protocol></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get protocol tcp"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><system xmlns="urn:example:config"><protocol><tcp/></protocol></system></data></rpc-reply>]]>]]>$'

new "netconf commit protocol tcp"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf changing from TCP to UDP (RFC7950 7.9.6)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><protocol><udp nc:operation="create"/></protocol></system></config></edit-config></rpc>]]>]]>' '^<rpc-reply message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"><ok/></rpc-reply>]]>]]>$'

new "netconf get protocol udp"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><system xmlns="urn:example:config"><protocol><udp/></protocol></system></data></rpc-reply>]]>]]>$'

new "netconf commit protocol udp"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#-- restconf

new "restconf DELETE whole datastore"
expectpart "$(curl -sik -X DELETE $RCPROTO://localhost/restconf/data)" 0 "HTTP/1.1 204 No Content"

new "restconf set protocol tcp+udp fail"
expectpart "$(curl -sik -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/system:system/protocol -d '{"system:protocol":{"tcp": [null], "udp": [null]}}')" 0 "HTTP/1.1 400 Bad Request" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"bad-element","error-info":{"bad-element":"udp"},"error-severity":"error","error-message":"Element in choice statement already exists"}}}'

new "restconf set protocol tcp"
expectpart "$(curl -sik -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/system:system/protocol -d {\"system:protocol\":{\"tcp\":[null]}})" 0 "HTTP/1.1 201 Created"

new "restconf get protocol tcp"
expectpart "$(curl -sik -X GET $RCPROTO://localhost/restconf/data/system:system)" 0 "HTTP/1.1 200 OK" '{"system:system":{"protocol":{"tcp":\[null\]}}}'

new "restconf set protocol tcp+udp fail again"
expectpart "$(curl -sik -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/system:system/protocol -d '{"system:protocol":{"tcp": [null], "udp": [null]}}')" 0 "HTTP/1.1 400 Bad Request" '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"bad-element","error-info":{"bad-element":"udp"},"error-severity":"error","error-message":"Element in choice statement already exists"}}}'

new "cli set protocol udp"
expectfn "$clixon_cli -1 -f $cfg -l o set system protocol udp" 0 "^$"

new "cli get protocol udp"
expectfn "$clixon_cli -1 -f $cfg -l o show configuration cli " 0 "^set system protocol udp$"

new "cli change protocol to tcp"
expectfn "$clixon_cli -1 -f $cfg -l o set system protocol tcp" 0 "^$"

new "cli get protocol tcp"
expectfn "$clixon_cli -1 -f $cfg -l o show configuration cli " 0 "^set system protocol tcp$"

new "cli delete all"
expectfn "$clixon_cli -1 -f $cfg -l o delete all" 0 "^$"

new "commit"
expectfn "$clixon_cli -1 -f $cfg -l o commit" 0 "^$"

# Second shorthand (no case)
new "netconf set protocol both udp and tcp"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><protocol><tcp/><udp/></protocol></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate both udp and tcp fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>udp</bad-element></error-info><error-severity>error</error-severity><error-message>Element in choice statement already exists</error-message></rpc-error></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf set shorthand tcp"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><shorthand><tcp/></shorthand></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf changing from TCP to UDP (RFC7950 7.9.6)"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><shorthand><udp/></shorthand></system></config></edit-config></rpc>]]>]]>' '^<rpc-reply message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"><ok/></rpc-reply>]]>]]>$'

new "netconf get shorthand udp"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><system xmlns="urn:example:config"><shorthand><udp/></shorthand></system></data></rpc-reply>]]>]]>$'

new "netconf validate shorthand"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Third check mandatory
new "netconf set empty mandatory"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><mandatory/></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get mandatory empty"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><system xmlns="urn:example:config"><mandatory/></system></data></rpc-reply>]]>]]>$'

new "netconf validate mandatory"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>data-missing</error-tag><error-app-tag>missing-choice</error-app-tag><error-info><missing-choice>name</missing-choice></error-info><error-severity>error</error-severity></rpc-error></rpc-reply>]]>]]>$'

new "netconf set mandatory udp"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config"><mandatory><udp/></mandatory></system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf get mandatory udp"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" '^<rpc-reply><data><system xmlns="urn:example:config"><mandatory><udp/></mandatory></system></data></rpc-reply>]]>]]>$'

new "netconf validate mandatory"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# Choice with multiple items

new "netconf choice multiple items first"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config" op="replace">
  <ma>0</ma>
  <ma>1</ma>
  <mb>2</mb>
</system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate multiple ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf choice multiple items second"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config" op="replace">
  <mb>0</mb>
  <mb>1</mb>
</system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate multiple ok"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf choice multiple items mix"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><system xmlns="urn:example:config" op="replace">
  <ma>0</ma>
  <mb>2</mb>
  <mc>2</mc>
</system></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate multiple error"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>bad-element</error-tag><error-info><bad-element>mc</bad-element></error-info><error-severity>error</error-severity><error-message>Element in choice statement already exists</error-message></rpc-error></rpc-reply>]]>]]>$'

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=$(pgrep -u root -f clixon_backend)
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

rm -rf $dir
