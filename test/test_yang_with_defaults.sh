#!/usr/bin/env bash

# Test of the IETF rfc6243: With-defaults Capability for NETCONF
#
# Test cases below follows the RFC.
#

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Uncomment if defined at compile time
# NETCONF_DEFAULT_RETRIEVAL_REPORT_ALL="report-all"

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
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_STREAM_DISCOVERY_RFC8040>true</CLICON_STREAM_DISCOVERY_RFC8040>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  $RESTCONFIG
</clixon-config>
EOF

# A.1.  Example YANG Module
# The following YANG module defines an example interfaces table to
# demonstrate how the <with-defaults> parameter behaves for a specific
# data model.
cat <<EOF > $fyang
module example {

     namespace "http://example.com/ns/interfaces";

     prefix exam;

     typedef status-type {
        description "Interface status";
        type enumeration {
          enum ok;
          enum 'waking up';
          enum 'not feeling so good';
          enum 'better check it out';
          enum 'better call for help';
        }
        default ok;
     }

     container interfaces {
         description "Example interfaces group";

         list interface {
           description "Example interface entry";
           key name;

           leaf name {
             description
               "The administrative name of the interface.
                This is an identifier that is only unique
                within the scope of this list, and only
                within a specific server.";
             type string {
               length "1 .. max";
             }
           }

           leaf mtu {
             description
               "The maximum transmission unit (MTU) value assigned to
                this interface.";
             type uint32;
             default 1500;
           }

           leaf status {
             description
               "The current status of this interface.";
             type status-type;
             config false;
           }
          }        
          container cedv {
                description 
                  "Container for test with explicit default value - EDV";
                leaf edv {
                  type string;
                  default "edv";
                }
          }
          container cdv {
                description 
                  "Container for test with  default value - DV";
                leaf dv {
                  type string;
                  default "dv";
                }
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

EXAMPLENS="xmlns=\"http://example.com/ns/interfaces\""

XML="<interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu></interface>\
<interface><name>eth1</name></interface>\
<interface><name>eth2</name><mtu>9000</mtu></interface>\
<interface><name>eth3</name><mtu>1500</mtu></interface>\
<cedv><edv>edv</edv></cedv>\
</interfaces>"

cat <<EOF > $fstate
<interfaces xmlns="http://example.com/ns/interfaces">
<interface><name>eth2</name><status>not feeling so good</status></interface>
<interface><name>eth3</name><status>waking up</status></interface>
</interfaces>
EOF


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
    new "start backend -s $db -f $cfg -- -sS $fstate"
    start_backend  -s $db -f $cfg -- -sS $fstate
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

new "rfc4243 4.3.  Capability Identifier"
expecteof "$clixon_netconf -ef $cfg" 0 "$DEFAULTHELLO" \
"<capability>urn:ietf:params:netconf:capability:with-defaults:1.0?basic-mode=explicit&amp;also-supported=report-all,trim,report-all-tagged</capability>"

new "rfc6243 3.1.  'report-all' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><mtu>1500</mtu><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
<cedv><edv>edv</edv></cedv><cdv><dv>dv</dv></cdv>\
</interfaces></data></rpc-reply>"

new "rfc6243 3.2.  'trim' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">trim</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu></interface>\
<interface><name>eth1</name></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><status>waking up</status></interface>\
</interfaces></data></rpc-reply>"

new "rfc6243 3.3.  'explicit' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">explicit</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
<cedv><edv>edv</edv></cedv>\
</interfaces></data></rpc-reply>"

new "rfc6243 3.4.  'report-all-tagged' Retrieval Mode"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter>\
<with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all-tagged</with-defaults></get></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS xmlns:wd=\"urn:ietf:params:xml:ns:netconf:default:1.0\">\
<interface><name>eth0</name><mtu>8192</mtu><status wd:default=\"true\">ok</status></interface>\
<interface><name>eth1</name><mtu wd:default=\"true\">1500</mtu><status wd:default=\"true\">ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu wd:default=\"true\">1500</mtu><status>waking up</status></interface>\
<cedv><edv wd:default=\"true\">edv</edv></cedv><cdv><dv wd:default=\"true\">dv</dv></cdv>\
</interfaces></data></rpc-reply>"

new "rfc6243 2.3.1.  'explicit' Basic Mode Retrieval"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
<cedv><edv>edv</edv></cedv>\
</interfaces></data></rpc-reply>" ""

new "rfc6243 2.3.3.  'explicit' <edit-config> and <copy-config> Behavior (part 1): create explicit node"
# A valid 'create' operation attribute for a data node that has
# been set by a client to its schema default value MUST fail with a
# 'data-exists' error-tag.
# (test: try to create mtu=3000 on interface eth3)
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>\
<interfaces $EXAMPLENS xmlns:nc=\"${BASENS}\">\
<interface><name>eth3</name><mtu nc:operation=\"create\">3000</mtu></interface>\
</interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" "" \
"<rpc-reply $DEFAULTNS><rpc-error>\
<error-type>application</error-type>\
<error-tag>data-exists</error-tag>\
<error-severity>error</error-severity>\
<error-message>Data already exists; cannot create new resource</error-message>\
</rpc-error></rpc-reply>"
# nothing to commit here, but just to verify

new "2.3.3 (part 1) commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# verify no change
new "2.3.3 (part 1) verify"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
<cedv><edv>edv</edv></cedv>\
</interfaces></data></rpc-reply>" ""

new "rfc6243 2.3.3.  'explicit' <edit-config> and <copy-config> Behavior (part 2): create default node"
# A valid 'create' operation attribute for a
# data node that has been set by the server to its schema default value
# MUST succeed.
# (test: set mtu=3000 on interface eth1)
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>\
<interfaces $EXAMPLENS xmlns:nc=\"${BASENS}\">\
<interface><name>eth1</name><mtu nc:operation=\"create\">3000</mtu></interface>\
</interfaces></config><default-operation>none</default-operation> </edit-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# commit change
new "2.3.3 (part 2) commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# verify that the mtu value has changed
new "2.3.3 (part 2) verify"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><mtu>3000</mtu><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
<cedv><edv>edv</edv></cedv>\
</interfaces></data></rpc-reply>" ""

new "rfc6243 2.3.3.  'explicit' <edit-config> and <copy-config> Behavior (part 3): delete explicit node"
#  A valid 'delete' operation attribute for a data node
#  that has been set by a client to its schema default value MUST
#  succeed.
# (test: try to delete mtu on interface eth1)
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>\
<interfaces $EXAMPLENS  xmlns:nc=\"${BASENS}\">\
<interface><name>eth1</name><mtu nc:operation=\"delete\"></mtu></interface>\
</interfaces></config><default-operation>none</default-operation></edit-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# commit delete
new "2.3.3 (part 3) commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# check that the default mtu vale has been restored
new "2.3.3 (part 3) verify"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
<cedv><edv>edv</edv></cedv>\
</interfaces></data></rpc-reply>" ""

new "rfc6243 2.3.3.  'explicit' <edit-config> and <copy-config> Behavior (part 4): delete default node"
# A valid 'delete' operation attribute for a data node that
# has been set by the server to its schema default value MUST fail with
# a 'data-missing' error-tag.
#(test: try to delete default mtu on interface eth1)
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>\
<interfaces $EXAMPLENS  xmlns:nc=\"${BASENS}\">\
<interface ><name>eth1</name><mtu nc:operation=\"delete\">1500</mtu></interface>\
</interfaces></config><default-operation>none</default-operation></edit-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><rpc-error>\
<error-type>application</error-type>\
<error-tag>data-missing</error-tag>\
<error-severity>error</error-severity>\
<error-message>Data does not exist; cannot delete resource</error-message>\
</rpc-error></rpc-reply>"

# nothing to commit
new "2.3.3 (part 4) commit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS ><commit/></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

# verify that the configuration has not changed
new "2.3.3 (part 4) verify"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get><filter type=\"subtree\"><interfaces $EXAMPLENS/></filter></get></rpc>" "" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface>\
<interface><name>eth1</name><status>ok</status></interface>\
<interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface>\
<interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface>\
<cedv><edv>edv</edv></cedv>\
</interfaces></data></rpc-reply>" ""

new "Pagination"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get-config>\
<source><running/></source>\
<filter type=\"xpath\" select=\"/e:interfaces/e:interface\" xmlns:e=\"http://example.com/ns/interfaces\"/>\
<list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><offset>1</offset><limit>2</limit></list-pagination>\
 </get-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth1</name></interface>\
<interface><name>eth2</name><mtu>9000</mtu></interface>\
</interfaces></data></rpc-reply>"

new "Pagination with-defaults=report-all"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get-config>\
<source><running/></source>\
<filter type=\"xpath\" select=\"/e:interfaces/e:interface\" xmlns:e=\"http://example.com/ns/interfaces\"/>\
<list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><offset>1</offset><limit>2</limit></list-pagination>\
 <with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults>\
 </get-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth1</name><mtu>1500</mtu></interface>\
<interface><name>eth2</name><mtu>9000</mtu></interface>\
</interfaces></data></rpc-reply>"

new "Pagination with-defaults=trim"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get-config>\
<source><running/></source>\
<filter type=\"xpath\" select=\"/e:interfaces/e:interface\" xmlns:e=\"http://example.com/ns/interfaces\"/>\
<list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><offset>1</offset><limit>2</limit></list-pagination>\
 <with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">trim</with-defaults>\
 </get-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth1</name></interface>\
<interface><name>eth2</name><mtu>9000</mtu></interface>\
</interfaces></data></rpc-reply>"

new "Pagination with-defaults=explicit"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get-config>\
<source><running/></source>\
<filter type=\"xpath\" select=\"/e:interfaces/e:interface\" xmlns:e=\"http://example.com/ns/interfaces\"/>\
<list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><offset>0</offset><limit>4</limit></list-pagination>\
 <with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">explicit</with-defaults>\
 </get-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS>\
<interface><name>eth0</name><mtu>8192</mtu></interface>\
<interface><name>eth1</name></interface>\
<interface><name>eth2</name><mtu>9000</mtu></interface>\
<interface><name>eth3</name><mtu>1500</mtu></interface>\
</interfaces></data></rpc-reply>"

new "Pagination with-defaults=report-all-tagged"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" \
"<rpc $DEFAULTNS><get-config>\
<source><running/></source>\
<filter type=\"xpath\" select=\"/e:interfaces/e:interface\" xmlns:e=\"http://example.com/ns/interfaces\"/>\
<list-pagination xmlns=\"urn:ietf:params:xml:ns:yang:ietf-list-pagination-nc\"><offset>0</offset><limit>4</limit></list-pagination>\
 <with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all-tagged</with-defaults>\
 </get-config></rpc>" \
"" \
"<rpc-reply $DEFAULTNS><data><interfaces $EXAMPLENS xmlns:wd=\"urn:ietf:params:xml:ns:netconf:default:1.0\">\
<interface><name>eth0</name><mtu>8192</mtu></interface>\
<interface><name>eth1</name><mtu wd:default=\"true\">1500</mtu></interface>\
<interface><name>eth2</name><mtu>9000</mtu></interface>\
<interface><name>eth3</name><mtu wd:default=\"true\">1500</mtu></interface>\
</interfaces></data></rpc-reply>"

new "rfc8040 4.3. RESTCONF GET json"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/example:interfaces)" \
0 \
"HTTP/$HVER 200" \
"Content-Type: application/yang-data+json" \
"Cache-Control: no-cache" \
'{"example:interfaces":{"interface":\[{"name":"eth0","mtu":8192,"status":"ok"},{"name":"eth1","status":"ok"},{"name":"eth2","mtu":9000,"status":"not feeling so good"},{"name":"eth3","mtu":1500,"status":"waking up"}\],"cedv":{"edv":"edv"}}}'

new "rfc8040 4.3. RESTCONF GET xml"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:interfaces)" \
0 \
"HTTP/$HVER 200" \
"Content-Type: application/yang-data+xml" \
"Cache-Control: no-cache" \
'<interfaces xmlns="http://example.com/ns/interfaces"><interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface><interface><name>eth1</name><status>ok</status></interface><interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface><interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface><cedv><edv>edv</edv></cedv></interfaces>'

new "rfc8040 B.1.3.  Retrieve the Server Capability Information json"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/capabilities)" \
0 \
"HTTP/$HVER 200" "Content-Type: application/yang-data+json" \
'Cache-Control: no-cache' \
'{"ietf-restconf-monitoring:capabilities":{"capability":\["urn:ietf:params:restconf:capability:defaults:1.0?basic-mode=explicit","urn:ietf:params:restconf:capability:depth:1.0","urn:ietf:params:restconf:capability:with-defaults:1.0"\]}}'

new "rfc8040 B.1.3.  Retrieve the Server Capability Information xml"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/ietf-restconf-monitoring:restconf-state/capabilities)" \
0 \
"HTTP/$HVER 200" "Content-Type: application/yang-data+xml" \
'Cache-Control: no-cache' \
'<capabilities xmlns="urn:ietf:params:xml:ns:yang:ietf-restconf-monitoring"><capability>urn:ietf:params:restconf:capability:defaults:1.0?basic-mode=explicit</capability><capability>urn:ietf:params:restconf:capability:depth:1.0</capability><capability>urn:ietf:params:restconf:capability:with-defaults:1.0</capability></capabilities>'

new "rfc8040 B.3.9. RESTCONF with-defaults parameter = report-all json"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/example:interfaces/interface=eth1?with-defaults=report-all)" \
0 \
"HTTP/$HVER 200" \
"Content-Type: application/yang-data+json" \
"Cache-Control: no-cache" \
'{"example:interface":\[{"name":"eth1","mtu":1500,"status":"ok"}\]}'

new "rfc8040 B.3.9. RESTCONF with-defaults parameter = report-all xml"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:interfaces/interface=eth1?with-defaults=report-all)" \
0 \
"HTTP/$HVER 200" \
"Content-Type: application/yang-data+xml" \
"Cache-Control: no-cache" \
'<interface xmlns="http://example.com/ns/interfaces"><name>eth1</name><mtu>1500</mtu><status>ok</status></interface>'

new "rfc8040 B.3.9. RESTONF with-defaults parameter = explicit json"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/example:interfaces/interface=eth1?with-defaults=explicit)" \
0 \
"HTTP/$HVER 200" \
"Content-Type: application/yang-data+json" \
"Cache-Control: no-cache" \
'{"example:interface":\[{"name":"eth1","status":"ok"}\]}'

new "rfc8040 B.3.9. RESTONF with-defaults parameter = explicit xml"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:interfaces/interface=eth1?with-defaults=explicit)" \
0 \
"HTTP/$HVER 200" \
"Content-Type: application/yang-data+xml" \
"Cache-Control: no-cache" \
'<interface xmlns="http://example.com/ns/interfaces"><name>eth1</name><status>ok</status></interface>'

new "rfc8040 B.3.9. RESTONF with-defaults parameter = trim json"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/example:interfaces/interface=eth3?with-defaults=trim)" \
0 \
"HTTP/$HVER 200" \
"Content-Type: application/yang-data+json" \
"Cache-Control: no-cache" \
'{"example:interface":\[{"name":"eth3","status":"waking up"}\]}'

new "rfc8040 B.3.9. RESTONF with-defaults parameter = trim xml"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:interfaces/interface=eth3?with-defaults=trim)" \
0 \
"HTTP/$HVER 200" \
"Content-Type: application/yang-data+xml" \
"Cache-Control: no-cache" \
'<interface xmlns="http://example.com/ns/interfaces"><name>eth3</name><status>waking up</status></interface>'

new "rfc8040 B.3.9. RESTCONF with-defaults parameter = report-all-tagged json"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+json' $RCPROTO://localhost/restconf/data/example:interfaces/interface=eth1?with-defaults=report-all-tagged)" \
0 \
"HTTP/$HVER 200" \
"Content-Type: application/yang-data+json" \
"Cache-Control: no-cache" \
'{"example:interface":\[{"name":"eth1","mtu":1500,"status":"ok","@mtu":{"ietf-netconf-with-defaults:default":true},"@status":{"ietf-netconf-with-defaults:default":true}}\]}'

new "rfc8040 B.3.9. RESTCONF with-defaults parameter = report-all-tagged xml"
expectpart "$(curl $CURLOPTS -X GET -H 'Accept: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example:interfaces/interface=eth1?with-defaults=report-all-tagged)" \
0 \
"HTTP/$HVER 200" \
"Content-Type: application/yang-data+xml" \
"Cache-Control: no-cache" \
'<interface xmlns="http://example.com/ns/interfaces" xmlns:wd="urn:ietf:params:xml:ns:netconf:default:1.0"><name>eth1</name><mtu wd:default="true">1500</mtu><status wd:default="true">ok</status></interface>'

# CLI tests
mode=explicit
new "cli with-default config $mode"
expectpart "$($clixon_cli -1 -f $cfg show config xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\"><interface><name>eth0</name><mtu>8192</mtu></interface><interface><name>eth1</name></interface><interface><name>eth2</name><mtu>9000</mtu></interface><interface><name>eth3</name><mtu>1500</mtu></interface><cedv><edv>edv</edv></cedv></interfaces>$"

new "cli with-default state $mode"
expectpart "$($clixon_cli -1 -f $cfg show state xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\"><interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface><interface><name>eth1</name><status>ok</status></interface><interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface><interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface><cedv><edv>edv</edv></cedv></interfaces>$"

mode=report-all
new "cli with-default config $mode"
expectpart "$($clixon_cli -1 -f $cfg show config xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\"><interface><name>eth0</name><mtu>8192</mtu></interface><interface><name>eth1</name><mtu>1500</mtu></interface><interface><name>eth2</name><mtu>9000</mtu></interface><interface><name>eth3</name><mtu>1500</mtu></interface><cedv><edv>edv</edv></cedv><cdv><dv>dv</dv></cdv></interfaces>$"

new "cli with-default state $mode"
expectpart "$($clixon_cli -1 -f $cfg show state xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\"><interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface><interface><name>eth1</name><mtu>1500</mtu><status>ok</status></interface><interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface><interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface><cedv><edv>edv</edv></cedv><cdv><dv>dv</dv></cdv></interfaces>$"

mode=report-all-tagged
new "cli with-default config $mode"
expectpart "$($clixon_cli -1 -f $cfg show config xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\" xmlns:wd=\"urn:ietf:params:xml:ns:netconf:default:1.0\"><interface><name>eth0</name><mtu>8192</mtu></interface><interface><name>eth1</name><mtu wd:default=\"true\">1500</mtu></interface><interface><name>eth2</name><mtu>9000</mtu></interface><interface><name>eth3</name><mtu wd:default=\"true\">1500</mtu></interface><cedv><edv wd:default=\"true\">edv</edv></cedv><cdv><dv wd:default=\"true\">dv</dv></cdv></interfaces>$"

new "cli with-default state $mode"
expectpart "$($clixon_cli -1 -f $cfg show state xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\" xmlns:wd=\"urn:ietf:params:xml:ns:netconf:default:1.0\"><interface><name>eth0</name><mtu>8192</mtu><status wd:default=\"true\">ok</status></interface><interface><name>eth1</name><mtu wd:default=\"true\">1500</mtu><status wd:default=\"true\">ok</status></interface><interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface><interface><name>eth3</name><mtu wd:default=\"true\">1500</mtu><status>waking up</status></interface><cedv><edv wd:default=\"true\">edv</edv></cedv><cdv><dv wd:default=\"true\">dv</dv></cdv></interfaces>$"

mode=trim
new "cli with-default config $mode"
expectpart "$($clixon_cli -1 -f $cfg show config xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\"><interface><name>eth0</name><mtu>8192</mtu></interface><interface><name>eth1</name></interface><interface><name>eth2</name><mtu>9000</mtu></interface><interface><name>eth3</name></interface></interfaces>$"

new "cli with-default state $mode"
expectpart "$($clixon_cli -1 -f $cfg show state xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\"><interface><name>eth0</name><mtu>8192</mtu></interface><interface><name>eth1</name></interface><interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface><interface><name>eth3</name><status>waking up</status></interface></interfaces>$"

mode=report-all-tagged-default
new "cli with-default config $mode"
expectpart "$($clixon_cli -1 -f $cfg show config xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\" xmlns:wd=\"urn:ietf:params:xml:ns:netconf:default:1.0\"><interface><name>eth0</name><mtu>8192</mtu></interface><interface><name>eth1</name><mtu>1500</mtu></interface><interface><name>eth2</name><mtu>9000</mtu></interface><interface><name>eth3</name><mtu>1500</mtu></interface><cedv><edv>edv</edv></cedv><cdv><dv>dv</dv></cdv></interfaces>$"

new "cli with-default state $mode"
expectpart "$($clixon_cli -1 -f $cfg show state xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\" xmlns:wd=\"urn:ietf:params:xml:ns:netconf:default:1.0\"><interface><name>eth0</name><mtu>8192</mtu><status>ok</status></interface><interface><name>eth1</name><mtu>1500</mtu><status>ok</status></interface><interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface><interface><name>eth3</name><mtu>1500</mtu><status>waking up</status></interface><cedv><edv>edv</edv></cedv><cdv><dv>dv</dv></cdv></interfaces>$"

mode=report-all-tagged-strip
new "cli with-default config $mode"
expectpart "$($clixon_cli -1 -f $cfg show config xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\" xmlns:wd=\"urn:ietf:params:xml:ns:netconf:default:1.0\"><interface><name>eth0</name><mtu>8192</mtu></interface><interface><name>eth1</name></interface><interface><name>eth2</name><mtu>9000</mtu></interface><interface><name>eth3</name></interface></interfaces>$"

new "cli with-default state $mode"
expectpart "$($clixon_cli -1 -f $cfg show state xml default $mode interfaces)" 0 "^<interfaces xmlns=\"http://example.com/ns/interfaces\" xmlns:wd=\"urn:ietf:params:xml:ns:netconf:default:1.0\"><interface><name>eth0</name><mtu>8192</mtu></interface><interface><name>eth1</name></interface><interface><name>eth2</name><mtu>9000</mtu><status>not feeling so good</status></interface><interface><name>eth3</name><status>waking up</status></interface></interfaces>$"

mode=negative-test
new "cli with-default config $mode"
expectpart "$($clixon_cli -1 -f $cfg -l o show config xml default $mode)" 255 "Unknown command"

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
