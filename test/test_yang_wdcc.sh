#!/usr/bin/env bash

# Test of the IETF rfc6243: With-defaults Capability for NETCONF
#
# Test cases below represents a corner case where the topmost container will be trimmed.
#

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example-default.yang
fstate=$dir/state.xml
clispec=$dir/spec.cli
RESTCONFIG=$(restconf_config none false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_MODULE_SET_ID>42</CLICON_MODULE_SET_ID>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>$dir</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>$dir/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  $RESTCONFIG
</clixon-config>
EOF

# Corner case model

cat <<EOF > $fyang
module example {

     namespace "http://example.com/ns/wdcc";

     prefix wdcc;

     container wd {
         description "With-defaults container";

           leaf wdc {
             description "With-defaults config";
             type uint32;
             default 1500;
           }
           leaf wdce {
             description "With-defaults config explicit";
             type uint32;
             default 1500;
           }
           leaf wds {
             description "Width-defaults state";
             type string;
             config false;
             default "ok";
          }
     }
}
EOF

# CLIspec for cli tests
cat <<EOF > $clispec
CLICON_MODE="example";
CLICON_PROMPT="%U@%H %W> ";
CLICON_PLUGIN="example_cli";

set @datamodel, cli_auto_set();
validate("Validate changes"), cli_validate();
commit("Commit the changes"), cli_commit();
quit("Quit"), cli_quit();
discard("Discard edits (rollback 0)"), discard_changes();
show("Show a particular state of the system"){
    configuration("Show configuration")
     xml("Show configuration and state as XML")
      default("With-default mode"){
          report-all @datamodelshow, cli_show_auto("candidate", "xml", false, false, "report-all");
          trim @datamodelshow, cli_show_auto("candidate", "xml", false, false, "trim");
          explicit @datamodelshow, cli_show_auto("candidate", "xml", false, false, "explicit");
          report-all-tagged @datamodelshow, cli_show_auto("candidate", "xml", false, false, "report-all-tagged");
          report-all-tagged-default @datamodelshow, cli_show_auto("candidate", "xml", false, false, "report-all-tagged-default");
          report-all-tagged-strip @datamodelshow, cli_show_auto("candidate", "xml", false, false, "report-all-tagged-strip");
    }
    state("Show configuration and state")
     xml("Show configuration and state as XML")
      default("With-default mode"){
          report-all @datamodelshow, cli_show_auto("running", "xml", false, true, "report-all");
          trim @datamodelshow, cli_show_auto("running", "xml", false, true, "trim");
          explicit @datamodelshow, cli_show_auto("running", "xml", false, true, "explicit");
          report-all-tagged @datamodelshow, cli_show_auto("running", "xml", false, true, "report-all-tagged");
          report-all-tagged-default @datamodelshow, cli_show_auto("running", "xml", false, true, "report-all-tagged-default");
          report-all-tagged-strip @datamodelshow, cli_show_auto("running", "xml", false, true, "report-all-tagged-strip");
    }
}
EOF

# A.2.  Example  Data Set

EXAMPLENS="xmlns=\"http://example.com/ns/wdcc\""

XML="<wd $EXAMPLENS><wdce>1500</wdce></wd>"


db=startup
if [ $db = startup ]; then
    sudo echo "<${DATASTORE_TOP}>$XML</${DATASTORE_TOP}>" > $dir/startup_db
fi
if [ $BE -ne 0 ]; then     # Bring your own backend
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend -s $db -f $cfg"
    start_backend  -s $db -f $cfg
fi

new "wait backend"
wait_backend

# permission kludges
new "chmod datastores"
sudo chmod 666 $dir/running_db
if [ $? -ne 0 ]; then
    err1 "chmod $dir/running_db"
fi
sudo chmod 666 $dir/startup_db
if [ $? -ne 0 ]; then
    err1 "chmod $dir/startup_db"
fi

new "Checking startup unchanged"
ret=$(diff $dir/startup_db <(echo "<${DATASTORE_TOP}>$XML</${DATASTORE_TOP}>"))
if [ $? -ne 0 ]; then
    err "<${DATASTORE_TOP}>$XML</${DATASTORE_TOP}>" "$ret"
fi

new "Checking running unchanged"
ret=$(diff $dir/running_db <(echo -n "<${DATASTORE_TOP}>$XML</${DATASTORE_TOP}>"))
if [ $? -ne 0 ]; then
    err "<${DATASTORE_TOP}>$XML</${DATASTORE_TOP}>" "$ret"
fi

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg
fi

new "wait restconf"
wait_restconf

new "rfc6243 3.1.  'report-all' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><wd $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><wd $EXAMPLENS>\
<wdc>1500</wdc><wdce>1500</wdce><wds>ok</wds>\
</wd></data></rpc-reply>"


new "rfc6243 3.2.  'trim' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><wd $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">trim</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data/></rpc-reply>"

new "rfc6243 3.3.  'explicit' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><wd $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">explicit</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><wd $EXAMPLENS>\
<wdce>1500</wdce><wds>ok</wds>\
</wd></data></rpc-reply>"

new "rfc6243 3.4.  'report-all-tagged' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><wd $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all-tagged</with-defaults></get></rpc>" \
"<rpc-reply $DEFAULTNS><data><wd xmlns=\"http://example.com/ns/wdcc\" xmlns:wd=\"urn:ietf:params:xml:ns:netconf:default:1.0\">\
<wdc wd:default=\"true\">1500</wdc><wdce wd:default=\"true\">1500</wdce><wds wd:default=\"true\">ok</wds>\
</wd></data></rpc-reply>"

new "rfc6243 2.3.1.  'explicit' Basic Mode Retrieval"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><wd $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><wd $EXAMPLENS>\
<wdce>1500</wdce><wds>ok</wds>\
</wd></data></rpc-reply>"


new "rfc8040 B.3.9. RESTONF with-defaults parameter = trim json"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/example:wd?with-defaults=trim)" \
0 \
"HTTP/$HVER 404" \
"Content-Type: application/yang-data+json" \
'{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"invalid-value","error-severity":"error","error-message":"Instance does not exist"}}}'

new "rfc8040 B.3.9. RESTONF with-defaults parameter = trim xml"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:wd?with-defaults=trim)" \
0 \
"HTTP/$HVER 404" \
"Content-Type: application/yang-data+xml" \
'<errors xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf"><error><error-type>application</error-type><error-tag>invalid-value</error-tag><error-severity>error</error-severity><error-message>Instance does not exist</error-message></error></errors>'

# CLI tests

mode=trim
new "cli with-default config $mode"
expectpart "$($clixon_cli -1 -f $cfg show config xml default $mode wd)" 0 ""

new "cli with-default state $mode"
expectpart "$($clixon_cli -1 -f $cfg show state xml default $mode wd)" 0 ""

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

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

rm -rf $dir

new "endtest"
endtest
