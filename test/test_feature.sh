#!/usr/bin/env bash
# Yang features. if-feature.
# The test has a example module with FEATURES A and B, where A is enabled and
# B is disabled.
# It also uses an ietf-router module where (only) router-id is enabled
# Also check modules-state (RFC7895) announces the enabled features.
#
# From RFC7950:
# 7.20.1 Schema nodes tagged with an "if-feature" statement are _ignored_ by
# the server unless the server supports the given feature expression.
# 8.1: There MUST be no nodes tagged with "if-feature" present if the
#  "if-feature" expression evaluates to "false" in the server.
# - Should the server just "ignore" these nodes or actively reject them?
#
# Clixon has a strict implementation of the features so that setting
# data with disabled features is same as if they are not present in the Yang.
# Which means no cli syntax or edit operations were syntactically allowed
# (and therefore invalid).

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang

# Note ietf-routing@2018-03-13 assumed
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>$APPNAME:A</CLICON_FEATURE>
  <CLICON_FEATURE>$APPNAME:A1</CLICON_FEATURE>
  <CLICON_FEATURE>ietf-routing:router-id</CLICON_FEATURE>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   import ietf-routing {
	prefix rt;
   }
   feature A{
      description "This test feature is enabled";
   }
   feature A1{
      description "This test feature is enabled (extra for multiple)";
   }
   feature B{
      description "This test feature is disabled";
   }
   feature B1{
      description "This test feature is disabled (extra for multiple)";
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
   leaf m1{
     if-feature "A and 
        A1";
     description "Enabled";
     type "string";
   }
   leaf m2{
     if-feature "A or 
        A1";
     description "Enabled";
     type "string";
   }
   leaf m3{
     if-feature "A and B";
     description "Not enabled";
     type "string";
   }
   leaf m4{
     if-feature "A or B";
     description "Enabled";
     type "string";
   }
   leaf m5{
     if-feature "B and B1";
     description "Not enabled";
     type "string";
   }
   leaf m6{
     if-feature "B or B1";
     description "Not enabled";
     type "string";
   }
   leaf m7{
     if-feature "A or A1 or B or B1";
     description "Enabled";
     type "string";
   }
   leaf m8{
     if-feature "A and A1 and B and B1";
     description "Not enabled";
     type "string";
   }
   leaf m9{
     if-feature "(A or B "
      	       + "or B1) and A1";
     description "Enabled";
     type "string";
   }
   leaf m10{
     if-feature "(A and A1 "
      	       + "and B1) or not A";
     description "Disabled";
     type "string";
   }
   leaf m11{
     if-feature "not (A or B)";
     description "Disabled";
     type "string";
   }
}
EOF

# Run netconf feature test
# 1: syntax node
# 2: disabled or enabled
# NOTE, this was before failures when disabled, but after https://github.com/clicon/clixon/issues/322 that
# disabled nodes should be "ignored". Instead now if disabled a random node is inserted under the disabled node
# which should not work 
function testrun()
{
    node=$1
    enabled=$2
    
    new "netconf set $node"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><$node xmlns=\"urn:example:clixon\">foo</$node></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    new "netconf validate $node"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

    if $enabled; then
	new "netconf set extra element under $node (expect fail)"
	expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><$node xmlns=\"urn:example:clixon\"><kallekaka/></$node></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>kallekaka</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: kallekaka with parent: $node in namespace: urn:example:clixon</error-message></rpc-error></rpc-reply>"
    else
	new "netconf set extra element under $node"
	expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><$node xmlns=\"urn:example:clixon\"><kallekaka/></$node></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

	new "netconf validate $node"
	expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
    fi

    new "netconf discard-changes"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"
}

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

new "wait backend"
wait_backend

new "cli enabled feature"
expectpart "$($clixon_cli -1f $cfg set x foo)" 0 ""

new "cli disabled feature"
expectpart "$($clixon_cli -1f $cfg -l o set y foo)" 255 "CLI syntax error: \"set y foo\": Unknown command"

new "cli enabled feature in other module"
expectpart "$($clixon_cli -1f $cfg set routing router-id 1.2.3.4)" 0 ""

new "cli disabled feature in other module"
expectpart "$($clixon_cli -1f $cfg -l o set routing ribs rib default-rib false)" 255 "CLI syntax error: \"set routing ribs rib default-rib false\": Unknown command"

new "netconf discard-changes"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><discard-changes/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# Single if-feature
testrun x true

testrun y false

# Multiple if-feature
testrun m1 true
testrun m2 true
testrun m3 false
testrun m4 true
testrun m5 false
testrun m6 false
testrun m7 true
testrun m8 false
testrun m9 true
testrun m10 false
testrun m11 false

# This test has been broken up into all different modules instead of one large
# reply since the modules change so often
new "netconf schema resource, RFC 7895"
rpc=$(chunked_framing "<rpc $DEFAULTNS><get><filter type=\"xpath\" select=\"l:yang-library/l:module-set[l:name='default']/l:module\" xmlns:l=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\"/></get></rpc>")
ret=$($clixon_netconf -qf $cfg<<EOF 
$DEFAULTHELLO$rpc
EOF
   )
#echo $ret

new "netconf yang-library header"
expect="^<rpc-reply $DEFAULTNS><data><yang-library xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\"><module-set><name>default</name><module><name>"
match=`echo "$ret" | grep --null -Go "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

new "netconf module A"
expect="<module><name>example</name><revision/><namespace>urn:example:clixon</namespace><feature>A</feature><feature>A1</feature></module>"
match=`echo "$ret" | grep --null -Go "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

if false ; then # clixon "config" is a meta-config and not visisble in regular features
new "netconf module clixon-config"
expect="<module><name>clixon-config</name><revision>2018-09-30</revision><namespace/></module>"
match=`echo "$ret" | grep --null -Go "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi
fi # false

new "netconf module ietf-inet-types"
expect="<module><name>ietf-inet-types</name><revision>2021-02-22</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-inet-types</namespace></module>"
match=`echo "$ret" | grep --null -Go "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

new "netconf module ietf-interfaces"
expect="<module><name>ietf-interfaces</name><revision>2018-02-20</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-interfaces</namespace></module>"
match=`echo "$ret" | grep --null -Go "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

# Note order of features in ietf-netconf yang is alphabetically: candidate, startup, validate, xpath
new "netconf module ietf-netconf"
expect="<module><name>ietf-netconf</name><revision>2011-06-01</revision><namespace>urn:ietf:params:xml:ns:netconf:base:1.0</namespace><feature>candidate</feature><feature>validate</feature><feature>xpath</feature></module>"
match=`echo "$ret" | grep --null -Go "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

new "netconf module ietf-routing"
expect="<module><name>ietf-routing</name><revision>2018-03-13</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-routing</namespace><feature>router-id</feature></module>"
match=`echo "$ret" | grep --null -Go "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi
expect="<module><name>ietf-yang-library</name><revision>2019-01-04</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-yang-library</namespace></module>"
match=`echo "$ret" | grep --null -Go "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
fi

new "netconf module ietf-yang_types"
expect="<module><name>ietf-yang-types</name><revision>2013-07-15</revision><namespace>urn:ietf:params:xml:ns:yang:ietf-yang-types</namespace></module>"
match=`echo "$ret" | grep --null -Go "$expect"`
if [ -z "$match" ]; then
      err "$expect" "$ret"
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

#------------------------
# Negative test, if if-feature but no feature, signal error
cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;
   feature A{
      description "This feature exists";
   }
   leaf x{
     if-feature "A or B";
     type "string";
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

    new "start backend -s init -f $cfg: feature missing expected fail"
    expectpart "$(sudo $clixon_backend -F1s init -f $cfg -l o)" 255 " Yang module example has IF_FEATURE B, but no such FEATURE statement exists"

    stop_backend -f $cfg
fi

unset ret

endtest

rm -rf $dir
