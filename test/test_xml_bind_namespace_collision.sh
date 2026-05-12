#!/usr/bin/env bash
# Reproduce sibling namespace collision during XML/YANG bind/translate.
# Two modules use the same local root/container/list names, but different
# namespaces. The UM branch is valid in its own module, but show/translate
# currently binds its <secret><ten> subtree against the locald module.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = "$0" ]; then exit 0; else return 0; fi

APPNAME=example

clispec=$dir/$APPNAME/clispec
mkdir -p "$clispec"

dbdir=$(mktemp -d "$dir/${APPNAME}.xmldb.XXXXXX")
rundir=$(mktemp -d "$dir/${APPNAME}.run.XXXXXX")

chmod 777 "$dbdir" "$rundir"

cfg=$dir/conf_yang.xml

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>*:*</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>$clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$rundir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>$rundir/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dbdir</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $clispec/example_cli.cli
CLICON_MODE="$APPNAME";
CLICON_PROMPT="%U@%H %W> ";

show("Show a particular state of the system"){
    configuration("Show configuration"), cli_show_config("running", "xml", "/");
}
quit("Quit"), cli_quit();
EOF

cat <<'EOF' > $dir/Cisco-IOS-XR-aaa-lib-cfg@2020-10-22.yang
module Cisco-IOS-XR-aaa-lib-cfg {
  yang-version 1.1;
  namespace "http://cisco.com/ns/yang/Cisco-IOS-XR-aaa-lib-cfg";
  prefix aaa-lib;

  revision 2020-10-22;

  container aaa;
}
EOF

cat <<'EOF' > $dir/Cisco-IOS-XR-aaa-locald-cfg@2022-11-28.yang
module Cisco-IOS-XR-aaa-locald-cfg {
  yang-version 1.1;
  namespace "http://cisco.com/ns/yang/Cisco-IOS-XR-aaa-locald-cfg";
  prefix aaa-locald;

  import Cisco-IOS-XR-aaa-lib-cfg {
    prefix aaa-lib;
  }

  revision 2022-11-28;

  augment "/aaa-lib:aaa" {
    container usernames {
      list username {
        key "ordering-index name";
        leaf ordering-index {
          type uint32;
        }
        leaf name {
          type string;
        }
        container secret {
          leaf type {
            type enumeration {
              enum type10;
            }
          }
          leaf secret10 {
            when "../type = 'type10'";
            type string;
          }
        }
      }
    }
  }
}
EOF

cat <<'EOF' > $dir/Cisco-IOS-XR-um-aaa-cfg@2023-09-07.yang
module Cisco-IOS-XR-um-aaa-cfg {
  yang-version 1.1;
  namespace "http://cisco.com/ns/yang/Cisco-IOS-XR-um-aaa-cfg";
  prefix um-aaa;

  revision 2023-09-07;

  container aaa;
}
EOF

cat <<'EOF' > $dir/Cisco-IOS-XR-um-aaa-task-user-cfg@2023-02-15.yang
module Cisco-IOS-XR-um-aaa-task-user-cfg {
  yang-version 1.1;
  namespace "http://cisco.com/ns/yang/Cisco-IOS-XR-um-aaa-task-user-cfg";
  prefix um-aaa-task-user;

  import Cisco-IOS-XR-um-aaa-cfg {
    prefix um-aaa;
  }

  revision 2023-02-15;

  augment "/um-aaa:aaa" {
    container usernames {
      list username {
        key "ordering-index name";
        leaf ordering-index {
          type uint32;
        }
        leaf name {
          type string;
        }
        container secret {
          leaf ten {
            type string;
          }
        }
      }
    }
  }
}
EOF

cat <<'EOF' > $dbdir/startup_db
<config>
  <aaa xmlns="http://cisco.com/ns/yang/Cisco-IOS-XR-aaa-lib-cfg">
    <usernames xmlns="http://cisco.com/ns/yang/Cisco-IOS-XR-aaa-locald-cfg">
      <username>
        <ordering-index>0</ordering-index>
        <name>root</name>
        <secret>
          <type>type10</type>
          <secret10>xx</secret10>
        </secret>
      </username>
    </usernames>
  </aaa>
  <aaa xmlns="http://cisco.com/ns/yang/Cisco-IOS-XR-um-aaa-cfg">
    <usernames xmlns="http://cisco.com/ns/yang/Cisco-IOS-XR-um-aaa-task-user-cfg">
      <username>
        <ordering-index>0</ordering-index>
        <name>root</name>
        <secret>
          <ten>xx</ten>
        </secret>
      </username>
    </usernames>
  </aaa>
</config>
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    $clixon_backend -z -f $cfg >/dev/null 2>&1 || true
    new "start backend -s startup -f $cfg"
    $clixon_backend -D $DBG -s startup -f $cfg
    if [ $? -ne 0 ]; then
        err
    fi
fi

new "wait backend"
wait_backend

new "show configuration preserves namespace-specific secret leaves"
expectpart "$($clixon_cli -1 -f $cfg show configuration 2>&1)" 0 \
    "<aaa xmlns=\"http://cisco.com/ns/yang/Cisco-IOS-XR-aaa-lib-cfg\">" \
    "<usernames xmlns=\"http://cisco.com/ns/yang/Cisco-IOS-XR-aaa-locald-cfg\">" \
    "<type>type10</type>" \
    "<secret10>xx</secret10>" \
    "<aaa xmlns=\"http://cisco.com/ns/yang/Cisco-IOS-XR-um-aaa-cfg\">" \
    "<usernames xmlns=\"http://cisco.com/ns/yang/Cisco-IOS-XR-um-aaa-task-user-cfg\">" \
    "<ten>xx</ten>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    $clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
        err "kill backend"
    fi
fi

rm -rf "$dir"

new "endtest"
endtest
