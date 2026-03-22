#!/usr/bin/env bash
# Clixon leaf-list default value test
# RFC 7950 Section 7.7.2: The default values of a leaf-list are the values
# that the server uses if the leaf-list does not exist in the data tree.
# The same ancestor-existence rules apply as for leaf defaults (Section 7.6.1).
#
# Cases tested:
# Top-level leaf-list with explicit "default" statements: defaults used from init
# Top-level leaf-list: default from type's default value
# leaf-list inside non-presence container: defaults used when ancestor exists
# leaf-list inside presence container: defaults only when container exists
# leaf-list user-ordered: default values preserve statement order
# Startup with leaf-list present: explicit values override defaults
# Startup with ancestor present but leaf-list absent: defaults used
# Ignore: leaf-list with min-elements >= 1: no default values apply ? (OH: I question this.)

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/leaflist_default.yang

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
</clixon-config>
EOF

cat <<EOF > $fyang
module example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;

    /* Top-level leaf-list with explicit default statements (RFC 7950 Sec 7.7.2)
     * Default values are the union of all "default" statements.
     * Used when the leaf-list does not exist in the data tree. */
    leaf-list ll1 {
        description "Top-level leaf-list with multiple defaults";
        type uint32;
        default 10;
        default 20;
        default 30;
    }

    /* Top-level leaf-list whose type has a default; leaf-list inherits it
     * (one instance of the type's default) when no min-elements >= 1 */
    typedef mytype {
        type string;
        default "typedefault";
    }
    leaf-list ll2 {
        description "Top-level leaf-list that inherits type default";
        type mytype;
    }

    /* Non-presence container: leaf-list defaults used when np-container exists */
    container np {
        description "Non-presence container";
        leaf trigger {
            type uint32;
        }
        leaf-list ll3 {
            description "leaf-list inside non-presence container";
            type uint32;
            default 100;
            default 200;
        }
    }

    /* Presence container: leaf-list defaults used only when container exists */
    container pres {
        presence "A presence container";
        description "Presence container";
        leaf-list ll4 {
            description "leaf-list inside presence container";
            type uint32;
            default 50;
            default 60;
        }
    }

    /* User-ordered leaf-list: RFC 7950 Sec 7.7.2 states defaults are used
     * in the order of the "default" statements */
    leaf-list ll5 {
        description "User-ordered leaf-list with defaults";
        type string;
        ordered-by user;
        default "first";
        default "second";
        default "third";
    }

    /* leaf-list with min-elements >= 1: no default values apply (Sec 7.7.2) */
    leaf-list ll6 {
        description "leaf-list with min-elements 1 - no defaults";
        type uint32;
        min-elements 1;
        default 99;
    }
}
EOF

NS='xmlns="urn:example:clixon"'
WD='xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults"'

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

# --- Empty config: no explicit values ---
new "get-config: empty (no explicit leaf-list values)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" \
    "<rpc-reply $DEFAULTNS><data/></rpc-reply>"

# --- report-all: top-level defaults present, np-container defaults present ---
new "get-config(report-all): top-level ll1 defaults"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><with-defaults $WD>report-all</with-defaults><source><candidate/></source></get-config></rpc>" "<ll1 $NS>10</ll1><ll1 $NS>20</ll1><ll1 $NS>30</ll1><ll2 $NS>typedefault</ll2><np $NS><ll3>100</ll3><ll3>200</ll3></np><ll5 $NS>first</ll5><ll5 $NS>second</ll5><ll5 $NS>third</ll5>"

# --- Instantiate presence container: ll4 defaults NOW present ---
new "edit-config: create presence container"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><pres $NS/></config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "get-config: presence container empty (no explicit ll4)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><data><pres $NS/></data></rpc-reply>"

new "get-config(report-all): ll4 defaults present after presence container created"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><with-defaults $WD>report-all</with-defaults><source><candidate/></source><filter type='subtree'><pres $NS/></filter></get-config></rpc>" \
    "<pres $NS><ll4>50</ll4><ll4>60</ll4></pres>"

# --- Explicit ll1 value: replaces all defaults ---
new "edit-config: set explicit ll1 value"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><ll1 $NS>99</ll1></config></edit-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "get-config: ll1 has explicit value (no defaults)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><data><ll1 $NS>99</ll1><pres $NS/></data></rpc-reply>"

new "get-config(report-all): ll1 explicit only, not default values"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><with-defaults $WD>report-all</with-defaults><source><candidate/></source></get-config></rpc>" \
    "<ll1 $NS>10</ll1><ll1 $NS>20</ll1><ll1 $NS>30</ll1><ll1 $NS>99</ll1>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    stop_backend -f $cfg
fi

# --- Startup: leaf-list absent, defaults apply ---
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
</${DATASTORE_TOP}>
EOF

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

new "get-config: empty startup -> ll1 defaults visible in report-all"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><with-defaults $WD>report-all</with-defaults><source><candidate/></source></get-config></rpc>" \
    "<ll1 $NS>10</ll1><ll1 $NS>20</ll1><ll1 $NS>30</ll1>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    stop_backend -f $cfg
fi

# --- Startup: leaf-list explicitly set, overrides defaults ---
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
  <ll1 xmlns="urn:example:clixon">77</ll1>
  <ll1 xmlns="urn:example:clixon">88</ll1>
</${DATASTORE_TOP}>
EOF

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s startup -f $cfg (explicit ll1)"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

new "get-config: explicit ll1 from startup (no defaults)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><data><ll1 $NS>77</ll1><ll1 $NS>88</ll1></data></rpc-reply>"

new "get-config(report-all): explicit ll1 only, default values not used"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><with-defaults $WD>report-all</with-defaults><source><candidate/></source></get-config></rpc>" \
    "<ll1 $NS>77</ll1><ll1 $NS>88</ll1>"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    stop_backend -f $cfg
fi

# --- Startup: presence container present -> ll4 defaults apply ---
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
  <pres xmlns="urn:example:clixon"/>
</${DATASTORE_TOP}>
EOF

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s startup -f $cfg (presence container)"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

new "get-config: presence container in startup -> ll4 defaults in report-all"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><with-defaults $WD>report-all</with-defaults><source><candidate/></source></get-config></rpc>" \
    "<pres $NS><ll4>50</ll4><ll4>60</ll4></pres>"

new "get-config(no report-all): presence container empty (ll4 not explicit)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
    "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" \
    "<rpc-reply $DEFAULTNS><data><pres $NS/></data></rpc-reply>"

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
