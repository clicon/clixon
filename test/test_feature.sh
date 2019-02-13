#!/bin/bash
# Yang features. if-feature. and schema resources according to RFC7895

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang

# Note ietf-routing@2018-03-13 assumed
cat <<EOF > $cfg
<config>
  <CLICON_FEATURE>$APPNAME:A</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-routing:router-id</CLICON_FEATURE>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MODULE_MAIN>$APPNAME</CLICON_YANG_MODULE_MAIN>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_CLI_GENMODEL_COMPLETION>1</CLICON_CLI_GENMODEL_COMPLETION>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</config>
EOF

cat <<EOF > $fyang
module $APPNAME{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   import ietf-routing {
	prefix rt;
   }
   feature A{
      description "This test feature is enabled";
   }
   feature B{
      description "This test feature is disabled";
   }
   feature C{
      description "This test feature is disabled";
   }
   leaf x{
     if-feature A;
     type "string";
   }
   leaf y{
     if-feature B;
     type "string";
   }
   leaf z{
     type "string";
   }
}
EOF

new "test params: -f $cfg -y $fyang"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg -y $fyang
    if [ $? -ne 0 ]; then
	err
    fi

    new "start backend -s init -f $cfg -y $fyang"
    # start new backend
    sudo $clixon_backend -s init -f $cfg -y $fyang -D $DBG
    if [ $? -ne 0 ]; then
	err
    fi
fi

new "cli enabled feature"
expectfn "$clixon_cli -1f $cfg -y $fyang set x foo" 0 ""

new "cli disabled feature"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set y foo" 255 "CLI syntax error: \"set y foo\": Unknown command"

new "cli enabled feature in other module"
expectfn "$clixon_cli -1f $cfg -y $fyang set routing router-id 1.2.3.4" 0 ""

new "cli disabled feature in other module"
expectfn "$clixon_cli -1f $cfg -l o -y $fyang set routing ribs rib default-rib false" 255 "CLI syntax error: \"set routing ribs rib default-rib\": Unknown command"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><discard-changes/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf enabled feature"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><x xmlns="urn:example:clixon">foo</x></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf validate enabled feature"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 "<rpc><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

new "netconf disabled feature"
expecteof "$clixon_netconf -qf $cfg -y $fyang" 0 '<rpc><edit-config><target><candidate/></target><config><y xmlns="urn:example:clixon">foo</y></config></edit-config></rpc>]]>]]>' '^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>y</bad-element></error-info><error-severity>error</error-severity><error-message>Unassigned yang spec</error-message></rpc-error></rpc-reply>]]>]]>$'

# This test has been broken up into all different modules instead of one large
# reply since the modules change so often
new "netconf schema resource, RFC 7895"
ret=$($clixon_netconf -qf $cfg -y $fyang<<EOF 
<rpc><get><filter type="xpath" select="modules-state/module" xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library"/></get></rpc>]]>]]>
EOF
)
new "netconf modules-state header"
expect='^<rpc-reply><data><modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library"><module><name>'
match=`echo "$ret" | grep -GZo "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

new "netconf module A"
expect="<module><name>example</name><revision/><namespace>urn:example:clixon</namespace><feature>A</feature><conformance-type>implement</conformance-type></module>"
match=`echo "$ret" | grep -GZo "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

if false ; then # clixon "config" bug
new "netconf module clixon-config"
expect="<module><name>clixon-config</name><revision>2018-09-30</revision><namespace/></module>"
match=`echo "$ret" | grep -GZo "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi
fi # false

new "netconf module ietf-inet-types"
expect="<module><name>ietf-inet-types</name><revision>2013-07-15</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-inet-types</namespace><conformance-type>implement</conformance-type></module>"
match=`echo "$ret" | grep -GZo "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

new "netconf module ietf-interfaces"
expect="<module><name>ietf-interfaces</name><revision>2018-02-20</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-interfaces</namespace><conformance-type>implement</conformance-type></module>"
match=`echo "$ret" | grep -GZo "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

# Note order of features in ietf-netconf yang is alphabetically: candidate, startup, validate, xpath
new "netconf module ietf-netconf"
expect="<module><name>ietf-netconf</name><revision>2011-06-01</revision><namespace>urn:ietf:params:xml:ns:netconf:base:1.0</namespace><feature>candidate</feature><feature>validate</feature><feature>startup</feature><feature>xpath</feature><conformance-type>implement</conformance-type></module>"
match=`echo "$ret" | grep -GZo "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

new "netconf module ietf-routing"
expect="<module><name>ietf-routing</name><revision>2018-03-13</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-routing</namespace><feature>router-id</feature><conformance-type>implement</conformance-type></module>"
match=`echo "$ret" | grep -GZo "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi
expect="<module><name>ietf-yang-library</name><revision>2016-06-21</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-yang-library</namespace><conformance-type>implement</conformance-type></module>"
match=`echo "$ret" | grep -GZo "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

new "netconf module ietf-yang_types"
expect="<module><name>ietf-yang-types</name><revision>2013-07-15</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-yang-types</namespace><conformance-type>implement</conformance-type></module>"
match=`echo "$ret" | grep -GZo "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

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
