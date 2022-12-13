#!/usr/bin/env bash
# yang augment and default values
# See https://github.com/clicon/clixon/issues/354
#
# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/augment.yang
fyang2=$dir/example.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
</clixon-config>
EOF

cat <<EOF > $fyang2
module example {
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  revision "2019-03-04";
  container table{
  }
}
EOF

cat <<EOF > $fyang
module augment {
   yang-version 1.1;
   namespace "urn:example:augment";
   prefix aug;
   import example {
      prefix ex;
   }
   revision "2019-03-04";
   augment "/ex:table" {
      container map{
         leaf name{
            type string;
         }
         leaf enable {
            type boolean;
            default true;
         }
      }
   }
}

EOF

cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
  <table xmlns="urn:example:clixon">
      <map xmlns="urn:example:augment">
         <name>me</name>
      </map>
  </table>
</${DATASTORE_TOP}>
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

new "cli show config startup"
expectpart "$($clixon_cli -1 -f $cfg -l o show config xml default report-all)" 0 '<table xmlns="urn:example:clixon">' '<map xmlns="urn:example:augment">' '<enable>true</enable>'

new "cli delete map name"
expectpart "$($clixon_cli -1 -f $cfg -l o delete table map name me)" 0 ""

new "cli show config deleted"
expectpart "$($clixon_cli -1 -f $cfg -l o show config xml default report-all)" 0 '<table xmlns="urn:example:clixon">' '<map xmlns="urn:example:augment">' '<enable>true</enable>'

new "cli set map name"
expectpart "$($clixon_cli -1 -f $cfg -l o set table map name x)" 0 ""

new "cli show config set"
expectpart "$($clixon_cli -1 -f $cfg -l o show config xml default report-all)" 0 '<table xmlns="urn:example:clixon">' '<map xmlns="urn:example:augment">' '<enable>true</enable>'

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

rm -rf $dir

new "endtest"
endtest
