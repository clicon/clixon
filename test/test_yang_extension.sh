#!/usr/bin/env bash
# Yang extensions and unknown statements.
# 1) First test syntax
# Assuming the following extension definition:
# prefix p;
# extension keyw {
#    argument arg; # optional
# }
# there are four forms of unknown statement as follows:
# p:keyw;
# p:keyw arg;
# p:keyw { stmt;* }
# p:keyw arg { stmt;* }
#
# 2) The extensions results in in a node data definition.
# Second, the example is run without the extension enabled, then it is enabled.
#
# @see test_cli_auto_extension

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/$APPNAME.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
</clixon-config>
EOF

cat <<EOF > $fyang
module $APPNAME{
   yang-version 1.1;
   prefix ex;
   namespace "urn:example:clixon";
   extension e1 {
      description "no argument, no statements";
   }
   extension e2 {
      description "with argument, no statements";
      argument arg;
   }
   extension e3 {
      description "no argument, with statement";
   }
   extension e4 {
      description "with argument, with statement";
      argument arg;
   }
   grouping foo {
     leaf foo{
       type string;
     }
   }
   grouping bar {
     leaf bar{
       type string;
     }
   }

   ex:e1;
   ex:e2 arg1;
   ex:e3 {
      uses foo;
   }
   ex:e4 arg1{
      uses bar;
   }
   extension posix-pattern {
      argument "pattern";
   }
   extension extra {
      argument "pattern"{} /* See https://github.com/clicon/clixon/issues/554 */
   }
   typedef dotted-quad {
      description "Only present for complex parsing of unknown-stmt";
      type string {
         pattern 
             "[a-f]" + "[0-9]";
         ex:posix-pattern
          // Strictly this comment is not supported if you see RFC syntax with only a SEP
          // in unknwon-stmt: identifier [sep string]
            '[f-w]' + '[o-q]';
      }
   }
}
EOF

XML='<foo xmlns="urn:example:clixon">a string</foo>'

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

# The main example implements ex:e4
new "Add extension foo (not implemented)"
expecteof_netconf "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><foo xmlns=\"urn:example:clixon\">a string</foo></config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>foo</bad-element></error-info><error-severity>error</error-severity>" ""

new "Add extension bar (is implemented)"
expecteof_netconf "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><bar xmlns=\"urn:example:clixon\">a string</bar></config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "netconf get config"
expecteof_netconf "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data><bar xmlns=\"urn:example:clixon\">a string</bar></data></rpc-reply>"

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

rm -rf $dir

new "endtest"
endtest
