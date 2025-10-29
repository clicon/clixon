#!/usr/bin/env bash
# YANG string quoting concatenation, see RFC7950 6.1.3
# RFC Section 14 contains several rules on the form: < a string that matches ...
#   If a quoted string is followed by a plus character ("+"), followed by
#   another quoted string, the two strings are concatenated
# See https://github.com/clicon/clixon-controller/issues/200

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = "$0" ]; then exit 0; else return 0; fi

APPNAME=example

#echo "Skipping test, Local and not committed."
#if [ "$s" = $0 ]; then exit 0; else return 0; fi
    
cfg=$dir/conf_yang.xml
fyang=$dir/example-server-farm.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
  module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    organization "This is a" +  // string
                 "multi-string organization";
    container "multistring"+  // identifier-arg-str
        "-table" {
           list parameter{
             key name;
               leaf name{
                type string;
            }
        }
    }
}
EOF

if [ $BE -ne 0 ]; then     # Bring your own backend
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

CONFIG="<multistring-table xmlns=\"urn:example:clixon\"><parameter><name>x</name></parameter></multistring-table>"

new "Add config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><default-operation>merge</default-operation><target><candidate/></target><config>$CONFIG</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Get config"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data>$CONFIG</data></rpc-reply>"


if [ $BE -ne 0 ]; then     # Bring your own backend
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
fi

rm -rf "$dir"

new "endtest"
endtest
