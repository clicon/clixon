#!/usr/bin/env bash
# Regression test for autocli grouping resolution in augmented trees.
# Reproduces failure pattern: "grouping <name> not found in" during clixon-cache read.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

dbdir=$(mktemp -d "$dir/${APPNAME}.xmldb.XXXXXX")
rundir=$(mktemp -d "$dir/${APPNAME}.run.XXXXXX")

chmod 777 "$dbdir" "$rundir"

cfg=$dir/conf_grouping_origin.xml
fcore=$dir/native-main.yang
faug=$dir/bfd-main.yang
cachedir=$dir/autocli

if [ ! -d $cachedir ]; then
    mkdir $cachedir
fi

cat <<EOF_CFG >$cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$faug</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>$dir/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>$dir/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$rundir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$rundir/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dbdir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_YANG_USE_ORIGINAL>true</CLICON_YANG_USE_ORIGINAL>
  <CLICON_AUTOCLI_CACHE_DIR>$cachedir</CLICON_AUTOCLI_CACHE_DIR>
  <autocli>
    <module-default>false</module-default>
    <list-keyword-default>kw-nokey</list-keyword-default>
    <grouping-treeref>true</grouping-treeref>
    <treeref-state-default>false</treeref-state-default>
    <clispec-cache>read</clispec-cache>
    <rule>
      <name>include all</name>
      <operation>enable</operation>
      <module-name>*</module-name>
    </rule>
  </autocli>
</clixon-config>
EOF_CFG

cat <<'EOF_CORE' >$fcore
module native-main {
  yang-version 1.1;
  namespace "urn:test:native-main";
  prefix nm;

  revision 2026-03-24;

  container native {
    leaf enabled {
      type boolean;
      default "true";
    }
    container bfd;
  }
}
EOF_CORE

cat <<'EOF_AUG' >$faug
module bfd-main {
  yang-version 1.1;
  namespace "urn:test:bfd-main";
  prefix bm;

  import native-main {
    prefix nm;
  }

  revision 2026-03-24;

  grouping config-bfd-grouping {
    grouping bfd-temp {
      leaf template-name {
        type string;
      }
    }

    container map {
      list ipv4 {
        key "name";
        leaf name {
          type string;
        }
        uses bfd-temp;
      }
    }
  }

  augment "/nm:native/nm:bfd" {
    uses config-bfd-grouping;
  }
}
EOF_AUG

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
sleep 1
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><ping $LIBNS/></rpc>" \
  "<ok/>"

new "clear autocli cache"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><clixon-cache $LIBNS><operation>clear</operation><type>autocli</type></clixon-cache></rpc>" \
  "<ok/>"

new "read autocli cache for module native-main (must not fail unresolved grouping)"
expecteof_netconf "$clixon_netconf -qef $cfg" 0 "$DEFAULTHELLO" \
  "<rpc $DEFAULTNS><clixon-cache $LIBNS><operation>read</operation><type>autocli</type><domain>top</domain><spec>data</spec><module>native-main</module><revision>2026-03-24</revision><keyword>module</keyword><argument>native-main</argument></clixon-cache></rpc>" \
  "<data"

# Regression scope ends here on purpose.
# The original bug manifests exactly at clixon-cache read for autocli.

if [ $BE -ne 0 ]; then
  new "Kill backend"
  pid=$(pgrep -u root -f clixon_backend)
  if [ -z "$pid" ]; then
    err "backend already dead"
  fi
  stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
