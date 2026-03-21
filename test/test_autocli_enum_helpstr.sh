#!/usr/bin/env bash
# Regression test for https://github.com/clicon/clixon/issues/183
# CLI help string for enum values should show per-enum description,
# not the enclosing leaf description.
# Tests both inline enum and typedef enum.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example.yang
clidir=$dir/cli

if [ -d $clidir ]; then
    rm -rf $clidir/*
else
    mkdir $clidir
fi

# Generate autocli for example module
AUTOCLI=$(autocli_config example kw-nokey false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>$clidir</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  ${AUTOCLI}
</clixon-config>
EOF

cat <<EOF > $clidir/ex.cli
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

set @datamodel, cli_auto_set();
EOF

# YANG module with:
# 1. A typedef with enum values each having their own description
# 2. A leaf using that typedef
# 3. A leaf with inline enum values each having descriptions
cat <<EOF > $fyang
module example {
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;

  typedef loglevel {
    type enumeration {
      enum none {
        description "NO log";
      }
      enum fatal {
        description "FATAL error";
      }
      enum error {
        description "ERROR condition";
      }
      enum warning {
        description "Warning condition";
      }
      enum info {
        description "Informational";
      }
      enum debug {
        description "Debug messages";
      }
    }
    description "General log level";
  }

  container crypto {
    leaf log {
      type ex:loglevel;
      description "crypto log level";
    }
    leaf status {
      description "device status";
      type enumeration {
        enum up {
          description "Device is up";
        }
        enum down {
          description "Device is down";
        }
        enum maintenance {
          description "Under maintenance";
        }
      }
    }
    leaf plain {
      description "plain enum leaf";
      type enumeration {
        enum alpha;
        enum beta;
        enum gamma;
      }
    }
  }
}
EOF

new "test params: -f $cfg"
if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -z -f $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

new "Generated CLI spec: typedef enum has per-enum descriptions"
expectpart "$($clixon_cli -f $cfg -G -1 2>&1)" 0 \
    'none("NO log")' \
    'fatal("FATAL error")' \
    'error("ERROR condition")' \
    'warning("Warning condition")' \
    'info("Informational")' \
    'debug("Debug messages")'

new "CLI help: typedef enum shows per-enum descriptions"
expectpart "$(echo "set crypto log ?" | $clixon_cli -f $cfg 2>&1)" 0 \
    "NO log" \
    "FATAL error" \
    "ERROR condition" \
    "Warning condition" \
    "Informational" \
    "Debug messages" \
    --not-- "crypto log level"

new "Generated CLI spec: inline enum has per-enum descriptions"
expectpart "$($clixon_cli -f $cfg -G -1 2>&1)" 0 \
    'up("Device is up")' \
    'down("Device is down")' \
    'maintenance("Under maintenance")'

new "CLI help: inline enum shows per-enum descriptions"
expectpart "$(echo "set crypto status ?" | $clixon_cli -f $cfg 2>&1)" 0 \
    "Device is up" \
    "Device is down" \
    "Under maintenance" \
    --not-- "device status"

new "CLI help: enum without per-value descriptions shows leaf description"
expectpart "$(echo "set crypto plain ?" | $clixon_cli -f $cfg 2>&1)" 0 \
    "alpha" \
    "beta" \
    "gamma" \
    "plain enum leaf"

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