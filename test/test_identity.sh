#!/usr/bin/env bash
# Identity and identityref tests
# Example from RFC7950 Sec 7.18 and 9.10

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example-my-crypto.yang

# Define default restconfig config: RESTCONFIG
restconf_config none false

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  $RESTCONFIG
</clixon-config>
EOF

# Example from RFC7950 Sec 7.18 and 9.10
# with two changes: the leaf statement is in the original module and
# a transitive dependent identifier (foo)
cat <<EOF > $dir/example-crypto-base.yang
     module example-crypto-base {
       yang-version 1.1;
       namespace "urn:example:crypto-base";
       prefix "crypto";

       identity crypto-alg {
         description
           "Base identity from which all crypto algorithms
            are derived.";
       }
       identity symmetric-key {
         description
           "Base identity used to identify symmetric-key crypto
            algorithms.";
         }
       identity public-key {
         description
           "Base identity used to identify public-key crypto
            algorithms.";
         }
       }

EOF

cat <<EOF > $dir/example-des.yang
     module example-des {
       yang-version 1.1;
       namespace "urn:example:des";
       prefix "des";
       import "example-crypto-base" {
         prefix "crypto";
       }
       identity des {
         base "crypto:crypto-alg";
         base "crypto:symmetric-key";
         description "DES crypto algorithm.";
       }
       identity des3 {
         base "crypto:crypto-alg";
         base "crypto:symmetric-key";
         description "Triple DES crypto algorithm.";
       }
     }
EOF

cat <<EOF > $fyang
     module example {
       yang-version 1.1;
       namespace "urn:example:my-crypto";
       prefix mc;
       import "example-crypto-base" {
         prefix "crypto";
       }
       import "example-des" {
         prefix "des";
       }
       identity aes {
         base "crypto:crypto-alg";
       }
       identity foo {
         description "transitive dependent identifier";
         base "des:des";
       }
       leaf crypto {
         description "Value can be any transitively derived from crypto-alg";
         type identityref {
           base "crypto:crypto-alg";
         }
       }
       container aes-parameters {
         when "../crypto = 'mc:aes'";
       }
       identity acl-base;
       typedef acl-type {
          description "problem detected in ietf-access-control-list.yang";
          type identityref {
             base acl-base;
          }
       }
       identity ipv4-acl-type {
          base mc:acl-base;
       }
       identity ipv6-acl-type {
          base mc:acl-base;
       }
       container acls { 
          list acl {
             key name;
             leaf name {
                type string;
             }
             leaf type {
	        type acl-type;
             }
          } 
       }
       identity empty; /* some errors with an empty identity set */
       leaf e {
          type identityref {
             base mc:empty;
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

new "Set crypto to aes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><crypto xmlns=\"urn:example:my-crypto\">aes</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate "
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Set crypto to mc:aes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><crypto xmlns=\"urn:example:my-crypto\">mc:aes</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Set crypto to des:des3"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><crypto xmlns=\"urn:example:my-crypto\">des:des3</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Set crypto to mc:foo"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><crypto xmlns=\"urn:example:my-crypto\">mc:foo</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Set crypto to des:des3 using xmlns"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><crypto xmlns=\"urn:example:my-crypto\" xmlns:des=\"urn:example:des\">des:des3</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

if false; then
# XXX this is not supported
new "Set crypto to x:des3 using xmlns"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><crypto xmlns=\"urn:example:my-crypto\" xmlns:x=\"urn:example:des\">x:des3</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"
fi # not supported

new "Set crypto to foo:bar"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><crypto xmlns=\"urn:example:my-crypto\">foo:bar</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate (expect fail)"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Identityref validation failed, foo:bar not derived from crypto-alg</error-message></rpc-error></rpc-reply>]]>]]>$"

new "cli set crypto to mc:aes"
expectpart "$($clixon_cli -1 -f $cfg -l o set crypto mc:aes)" 0 "^$"

new "cli validate"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 0 "^$"

new "cli set crypto to aes"
expectpart "$($clixon_cli -1 -f $cfg -l o set crypto aes)" 0 "^$"

new "cli validate"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 0 "^$"

new "cli set crypto to des:des3"
expectpart "$($clixon_cli -1 -f $cfg -l o set crypto des:des3)" 0 "^$"

new "cli validate"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 0 "^$"

new "Netconf set acl-type"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><acls xmlns=\"urn:example:my-crypto\"><acl><name>x</name><type>mc:ipv4-acl-type</type></acl></acls></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate "
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Netconf set undefined acl-type"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><acls xmlns=\"urn:example:my-crypto\"><acl><name>x</name><type>undefined</type></acl></acls></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf validate fail"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Identityref validation failed, undefined not derived from acl-base</error-message></rpc-error></rpc-reply>]]>]]>"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "CLI set acl-type"
expectpart "$($clixon_cli -1 -f $cfg -l o set acls acl x type mc:ipv4-acl-type)" 0 "^$"

new "cli validate"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 0 "^$"

new "CLI set wrong acl-type"
expectpart "$($clixon_cli -1 -f $cfg -l o set acls acl x type undefined)" 0 "^$"

new "cli validate acl-type"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 255 "Validate failed. Edit and try again or discard changes: application operation-failed Identityref validation failed, undefined not derived from acl-base"

# test empty identityref list
new "cli set empty"
expectpart "$($clixon_cli -1 -f $cfg -l o set e undefined)" 0 "^$"

new "cli validate empty"
expectpart "$($clixon_cli -1 -f $cfg -l o validate)" 255 "Validate failed. Edit and try again or discard changes: application operation-failed Identityref validation failed, undefined not derived from acl-base"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# restconf and identities:
# 1. set identity in own module with restconf (PUT and POST), read it with restconf and netconf
# 2. set identity in other module with restconf , read it with restconf and netconf
# 3. set identity in other module with netconf, read it with restconf and netconf
new "restconf add own identity"
expectpart "$(curl $CURLOPTS -X PUT -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example:crypto  -d '{"example:crypto":"example:aes"}')" 0 'HTTP/1.1 201 Created'

new "restconf get own identity"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:crypto)" 0 'HTTP/1.1 200 OK' '{"example:crypto":"aes"}'

new "netconf get own identity as set by restconf"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><crypto xmlns=\"urn:example:my-crypto\">aes</crypto>"

new "restconf delete identity"
expectpart "$(curl $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/example:crypto)" 0 "HTTP/1.1 204 No Content"

# 2. set identity in other module with restconf , read it with restconf and netconf
if ! $YANG_UNKNOWN_ANYDATA ; then
new "restconf add POST instead of PUT (should fail)"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data/example:crypto -d '{"example:crypto":"example-des:des3"}')" 0 'HTTP/1.1 400 Bad Request' '{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"crypto"},"error-severity":"error","error-message":"Failed to find YANG spec of XML node: crypto with parent: crypto in namespace: urn:example:my-crypto"}}}'
fi

# Alternative error:
#'{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"unknown-element","error-info":{"bad-element":"crypto"},"error-severity":"error","error-message":"Leaf contains sub-element"}}}'

new "restconf add other (des) identity using POST"
expectpart "$(curl $CURLOPTS -X POST -H "Content-Type: application/yang-data+json" $RCPROTO://localhost/restconf/data  -d '{"example:crypto":"example-des:des3"}')" 0 'HTTP/1.1 201 Created' "Location: $RCPROTO://localhost/restconf/data/example:crypto"

new "restconf get other identity"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:crypto)" 0 'HTTP/1.1 200 OK' '{"example:crypto":"example-des:des3"}'

new "netconf get other identity"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><crypto xmlns=\"urn:example:my-crypto\" xmlns:des=\"urn:example:des\">des:des3</crypto>"

new "restconf delete identity"
expectpart "$(curl $CURLOPTS -X DELETE $RCPROTO://localhost/restconf/data/example:crypto)" 0 "HTTP/1.1 204 No Content"

# 3. set identity in other module with netconf, read it with restconf and netconf
new "netconf set other identity"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><crypto xmlns=\"urn:example:my-crypto\" xmlns:des=\"urn:example:des\">des:des3</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf commit"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "restconf get other identity (set by netconf)"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example:crypto)" 0 'HTTP/1.1 200 OK' '{"example:crypto":"example-des:des3"}'

new "netconf get other identity"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><crypto xmlns=\"urn:example:my-crypto\" xmlns:des=\"urn:example:des\">des:des3</crypto>"

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

if [ $BE -eq 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
fi

endtest

# Set by restconf_config
unset RESTCONFIG

rm -rf $dir
