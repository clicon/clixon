#!/usr/bin/env bash
# yang augment and default values
# See https://github.com/clicon/clixon/issues/354
# Also: https://github.com/clicon/clixon/issues/712
#   leaf-list defaults in augmented nodes: ys_populate2 was called twice
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
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>true</CLICON_YANG_LIBRARY>
  <CLICON_CLI_OUTPUT_FORMAT>xml</CLICON_CLI_OUTPUT_FORMAT>
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
  grouping xpaths {
    container xp {
      leaf-list xpath {
        type string;
      }
    }
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
   augment "/ex:table" {
      leaf-list ll {             /* Case 1: plain leaf-list with defaults in augment */
         type string;
         default a;
         default b;
      }
      uses ex:xpaths {           /* Case 2: augment + uses + refine (controller case) */
         refine xp/xpath {
            default "/x/y";
         }
      }
      leaf-list dl {             /* Case 3: deviation adds default after augment */
         type string;
         default c;
      }
   }
   deviation "/ex:table/aug:dl" {
      deviate add {
         default d;
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

new "netconf get-config report-all: augmented leaf-list defaults appear once"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults><source><running/></source><filter type=\"subtree\"><table xmlns=\"urn:example:clixon\"/></filter></get-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><map xmlns=\"urn:example:augment\"><name>me</name><enable>true</enable></map><ll xmlns=\"urn:example:augment\">a</ll><ll xmlns=\"urn:example:augment\">b</ll><xp xmlns=\"urn:example:augment\"><xpath>/x/y</xpath></xp><dl xmlns=\"urn:example:augment\">c</dl><dl xmlns=\"urn:example:augment\">d</dl></table></data></rpc-reply>"

new "cli show config startup"
expectpart "$($clixon_cli -1 -f $cfg -l o show config default report-all)" 0 '<table xmlns="urn:example:clixon">' '<map xmlns="urn:example:augment">' '<enable>true</enable>'

new "cli delete map name"
expectpart "$($clixon_cli -1 -f $cfg -l o delete table map name me)" 0 ""

new "cli show config deleted"
expectpart "$($clixon_cli -1 -f $cfg -l o show config default report-all)" 0 '<table xmlns="urn:example:clixon">' '<map xmlns="urn:example:augment">' '<enable>true</enable>'

new "cli set map name"
expectpart "$($clixon_cli -1 -f $cfg -l o set table map name x)" 0 ""

new "cli show config set"
expectpart "$($clixon_cli -1 -f $cfg -l o show config default report-all)" 0 '<table xmlns="urn:example:clixon">' '<map xmlns="urn:example:augment">' '<enable>true</enable>'

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
