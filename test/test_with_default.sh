#!/usr/bin/env bash
# Netconf with default capability See RFC 6243
# Test what clixon has
# These are the modes defined in RFC 6243:
# o  report-all
# (o  report-all-tagged)
# o  trim
# o  explicit
# Clixon supports explicit, but the testcases define the other cases as well
# in case others will be supported
# XXX I dont think this is correct. Or at least it is not complete.

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example-default.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
   module example-default {
      namespace "urn:example:default";
      prefix "ex";
      typedef dt {
         description "Just a base type with a default value of 42";
          type int32;
          default 42;
      }
      container c{
        list x {
          key k;
          leaf k{
            type string;
          }
          leaf y {
            /* Three possible values: notset, default(42), other(eg 99) */
            type dt;
          }
        }
      }
   }
EOF

new "test params: -f $cfg"
# Bring your own backend
if [ $BE -ne 0 ]; then
    # kill old backend (if any)
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend  -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

# This is the base XML with three values in the server: notset, default, other
XML='<c xmlns="urn:example:default"><x><k>default</k><y>42</y></x><x><k>notset</k></x><x><k>other</k><y>99</y></x></c>'

# report-all: does not consider any data node to be default data,
# even schema default data. (noset is set to 42)
REPORT_ALL='<c xmlns="urn:example:default"><x><k>default</k><y>42</y></x><x><k>notset</k><y>42</y></x><x><k>other</k><y>99</y></x></c>'

# trim:  MUST consider any data node set to its schema default value to be
# default data (default is not set)
TRIM='<c xmlns="urn:example:default"><x><k>default</k></x><x><k>notset</k></x><x><k>other</k><y>99</y></x></c>'

# explicit:  MUST consider any data node that is not explicitly set data to
# be default data.
# (SAME AS Input XML)
EXPLICIT='<c xmlns="urn:example:default"><x><k>default</k><y>42</y></x><x><k>notset</k><y>42</y></x><x><k>other</k><y>99</y></x></c>'

new "Set defaults"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$XML</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

new "Check config (Clixon supports explicit)"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data>$EXPLICIT</data></rpc-reply>"

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
