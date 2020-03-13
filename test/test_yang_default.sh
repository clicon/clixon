#!/usr/bin/env bash
# Default handling and datastores.
# There was a bug with loading startup and writing it back to candidate/running
# where default mode in startup being "explicit" was transformed to "report-all"
# according to RFC 6243.
# Ie, all default values were populated.
# This test goes through (all) testcases where clixon writes data back to a datastore, and
# ensures default values are not present in the datastore.
# XXX two errors:
# 1. Running is changed
# XXX 2. type default not set

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
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
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
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
</clixon-config>
EOF

cat <<EOF > $fyang
   module example-default {
      namespace "urn:example:default";
      prefix "ex";
      typedef def {
         description "Just a base type with a default value of 42";
          type int32;
          default 42;
      }
      container a{
        list b {
          key c;
          leaf c{
            type string;
          }
          leaf d1 {
	    description "direct default";
	    type string;
            default "foo";
          }
          leaf d2 { /* <-- ys */
	    description "default in type";
            type def;
          }
        }
      }
   }
EOF

testrun(){

    # Initial data (default y not given)
    XML='<a xmlns="urn:example:default"><b><c>0</c></b></a>'

    db=startup
    if [ $db = startup ]; then
	sudo echo "<config>$XML</config>" > $dir/startup_db
    fi
    if [ $BE -ne 0 ]; then     # Bring your own backend
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s $db -f $cfg"
	start_backend -s $db -f $cfg
    fi
    
    new "waiting"
    wait_backend

    # permission kludges
    sudo chmod 666 $dir/running_db
    sudo chmod 666 $dir/startup_db

    new "Checking startup unchanged"
    ret=$(diff $dir/startup_db <(echo "<config>$XML</config>"))
    if [ $? -ne 0 ]; then
	err "<config>$XML</config>" "$ret"
    fi

    new "Checking running unchanged"
    ret=$(diff $dir/running_db <(echo -n "<config>$XML</config>"))
    if [ $? -ne 0 ]; then
	err "<config>$XML</config>" "$ret"
    fi

    new "check running defaults"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><get-config><source><running/></source></get-config></rpc>]]>]]>' '^<rpc-reply message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><data><a xmlns="urn:example:default"><b><c>0</c><d1>foo</d1><d2>42</d2></b></a></data></rpc-reply>]]>]]>$'

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
} # testrun

testrun

rm -rf $dir
