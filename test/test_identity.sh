#!/bin/bash
# Identity and identityref tests
APPNAME=example
# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyang=$dir/example-my-crypto.yang

cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>$fyang</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
</config>
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
     }
EOF

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err
fi
new "start backend  -s init -f $cfg -y $fyang"
# start new backend
sudo clixon_backend -s init -f $cfg -y $fyang # -D 1
if [ $? -ne 0 ]; then
    err
fi

new "Set crypto to aes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><crypto>aes</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate "
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Set crypto to mc:aes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><crypto>mc:aes</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Set crypto to des:des3"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><crypto>des:des3</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Set crypto to mc:foo"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><crypto>mc:foo</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Set crypto to des:des3 using xmlns"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><crypto xmlns:des=\"urn:example:des\">des:des3</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

# XXX this is not supported
#new "Set crypto to x:des3 using xmlns"
#expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><crypto xmlns:x=\"urn:example:des\">x:des3</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

#new "netconf validate"
#expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "Set crypto to foo:bar"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><edit-config><target><candidate/></target><config><crypto>foo:bar</crypto></config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-tag>operation-failed</error-tag><error-type>application</error-type><error-severity>error</error-severity><error-message>Identityref validation failed, foo:bar not derived from crypto-alg</error-message></rpc-error></rpc-reply>]]>]]>$"

new "cli set crypto to mc:aes"
expectfn "$clixon_cli -1 -f $cfg -l o set crypto mc:aes" 0 "^$"

new "cli validate"
expectfn "$clixon_cli -1 -f $cfg -l o validate" 0 "^$"

new "cli set crypto to aes"
expectfn "$clixon_cli -1 -f $cfg -l o set crypto aes" 0 "^$"

new "cli validate"
expectfn "$clixon_cli -1 -f $cfg -l o validate" 0 "^$"

new "cli set crypto to des:des3"
expectfn "$clixon_cli -1 -f $cfg -l o set crypto des:des3" 0 "^$"

new "cli validate"
expectfn "$clixon_cli -1 -f $cfg -l o validate" 0 "^$"

new "Kill backend"
# Check if still alive
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
