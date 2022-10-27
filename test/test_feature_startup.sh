#!/usr/bin/env bash
# Yang features. if-feature.
# The test has a example module with FEATURES A and B, where A is enabled and
# Ignore dont throw error, see https://github.com/clicon/clixon/issues/322

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/test.yang

# Note ietf-routing@2018-03-13 assumed
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module example{
   yang-version 1.1;
   namespace "urn:example:clixon";
   prefix ex;

   feature A{
      description "This test feature is enabled";
   }

    grouping mytop {
        container mycontainer {
            if-feature A;
            leaf myleaf {
                type string;
           }
       }
    }
    uses mytop;
}
EOF

cat<<EOF > $dir/startup_db
<${DATASTORE_TOP}>
     <mycontainer xmlns="urn:example:clixon">
      <myleaf>boo</myleaf>
   </mycontainer>
</${DATASTORE_TOP}>
EOF

#
testrun()
{
    opt=$1

    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi

    new "start backend -s startup -f $cfg"
    start_backend -s startup ${opt} -f $cfg

    new "wait backend"
    wait_backend
}


new "test params: -f $cfg"

new "enable feature A"
testrun "-o CLICON_FEATURE=example:A"

new "enable feature B, expect fail"
testrun "-o CLICON_FEATURE=example:B"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    # kill backend
    stop_backend -f $cfg
fi

unset ret

endtest

rm -rf $dir
