#!/usr/bin/env bash
# Starting clixon with outdated (or not) modules.
# It is a test of handling modstate, identifying invalid startups
# and entering failsafe
# No active upgrading of an outdated db is made
# This relies on storing RFC7895 YANG Module Library modules-state info
# in the datastore (or XML files?)
# The test is made with three Yang models A, B and C as follows:
# Yang module A has revisions "0814-01-28" and "2019-01-01"
# Yang module B has only revision "2019-01-01"
# Yang module C has only revision "2019-01-01"
# The system is started YANG modules:
#      A revision "2019-01-01"
#      B revision "2019-01-01"
# The (startup) configuration XML file has:
#      A revision "0814-01-28";
#      B revision "2019-01-01"
#      C revision "2019-01-01"
# Which means the following:
#      A has an obsolete version
#         containing a0 which has been removed, and a1 which is OK
#      B has a compatible version
#      C is not present in the system

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyangA0=$dir/A@0814-01-28.yang
fyangA1=$dir/A@2019-01-01.yang
fyangB=$dir/B@2019-01-01.yang

# Yang module A revision "0814-01-28"
# Note that this Yang model will exist in the DIR but will not be loaded
# by the system. Just here for reference
cat <<EOF > $fyangA0
module A{
  prefix a;
  namespace "urn:example:a";
  revision 0814-01-28;
  leaf a0{
    type string;
  }
  leaf a1{
    type string;
  }
}
EOF

# Yang module A revision "2019-01-01"
cat <<EOF > $fyangA1
module A{
  prefix a;
  namespace "urn:example:a";
  revision 2019-01-01;
  revision 0814-01-28;
  /*  leaf a0 has been removed */
  leaf a1{
    description "exists in both versions";
    type string;
  } 
  leaf a2{
    description "has been added";
    type string;
  }
}
EOF

# Yang module B revision "2019-01-01"
cat <<EOF > $fyangB
module B{
  prefix b;
  namespace "urn:example:b";
  revision 2019-01-01;
  leaf b{
    type string;
  }
}
EOF

# Yang module C revision "2019-01-01" (note not written to yang dir)
cat <<EOF > /dev/null
module C{
  prefix c;
  namespace "urn:example:c";
  revision 2019-01-01;
  leaf c{
    type string;
  }
}
EOF

# Create configuration
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <CLICON_XMLDB_UPGRADE_CHECKOLD>false</CLICON_XMLDB_UPGRADE_CHECKOLD>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
</clixon-config>
EOF

# Create failsafe db
cat <<EOF > $dir/failsafe_db
<${DATASTORE_TOP}>
   <a1 xmlns="urn:example:a">always work</a1>
</${DATASTORE_TOP}>
EOF

# Create compatible startup db
# startup config XML with following 
cat <<EOF > $dir/compat-valid.xml
<${DATASTORE_TOP}>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:a</namespace>
      </module>
      <module>
         <name>B</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:b</namespace>
      </module>
   </modules-state>
   <a1 xmlns="urn:example:a">always work</a1>
   <b xmlns="urn:example:b">other text</b>
</${DATASTORE_TOP}>
EOF

# Create compatible startup db
# startup config XML with following 
cat <<EOF > $dir/compat-invalid.xml
<${DATASTORE_TOP}>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:a</namespace>
      </module>
      <module>
         <name>B</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:b</namespace>
      </module>
   </modules-state>
   <a0 xmlns="urn:example:a">old version</a0>
   <a1 xmlns="urn:example:a">always work</a1>
   <b xmlns="urn:example:b">other text</b>
   <c xmlns="urn:example:c">bla bla</c>
</${DATASTORE_TOP}>
EOF


# Create non-compat valid startup db
# startup config XML with following (A obsolete, B OK, C lacking)
# But XML is OK
cat <<EOF > $dir/non-compat-valid.xml
<${DATASTORE_TOP}>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>0814-01-28</revision>
         <namespace>urn:example:a</namespace>
      </module>
      <module>
         <name>B</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:b</namespace>
      </module>
      <module>
         <name>C</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:c</namespace>
      </module>
   </modules-state>
   <a1 xmlns="urn:example:a">always work</a1>
   <b xmlns="urn:example:b">other text</b>
</${DATASTORE_TOP}>
EOF

# Create non-compat startup db
# startup config XML with following (A obsolete, B OK, C lacking)
cat <<EOF > $dir/non-compat-invalid.xml
<${DATASTORE_TOP}>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>0814-01-28</revision>
         <namespace>urn:example:a</namespace>
      </module>
      <module>
         <name>B</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:b</namespace>
      </module>
      <module>
         <name>C</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:c</namespace>
      </module>
   </modules-state>
   <a0 xmlns="urn:example:a">old version</a0>
   <a1 xmlns="urn:example:a">always work</a1>
   <b xmlns="urn:example:b">other text</b>
   <c xmlns="urn:example:c">bla bla</c>
</${DATASTORE_TOP}>
EOF

# Compatible startup with syntax errors
cat <<EOF > $dir/compat-err.xml
<${DATASTORE_TOP}>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:a</namespace>
      </module>
      <module>
         <name>B</name>
         <revision>2019-01-01</revision>
         <namespace>urn:example:b</namespace>
      </module>
   </modules-state>
   <<a3 xmlns="urn:example:a">always work</a2>
   <b xmlns="urn:example:b">other text
</${DATASTORE_TOP}>
EOF

#! Start system in given mode and check database contents
# Before script is called populate running_db and startup_db
# @param[in] modstate  Boolean: Tag datastores with RFC 7895 YANG Module Library
# @param[in] mode      Startup mode: init, none, running, or startup
# @param[in] exprun    Expected content of running-db
# @param[in] expstart  Check startup database or not if ""
runtest(){
    modstate=$1
    mode=$2
    exprun=$3  
    expstart=$4   

    new "test params: -f $cfg"
    # Bring your own backend
    if [ $BE -ne 0 ]; then
	# kill old backend (if any)
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s $mode -f $cfg -o \"CLICON_XMLDB_MODSTATE=$modstate\""
	start_backend -s $mode -f $cfg -o "CLICON_XMLDB_MODSTATE=$modstate"

#	new "Restart backend as eg follows: -Ff $cfg -s $mode -o \"CLICON_XMLDB_MODSTATE=$modstate\" ($BETIMEOUT s)"
    fi

    new "wait backend"
    wait_backend

    new "Check running db content"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS>$exprun</rpc-reply>]]>]]>$"

    # If given check startup db XML
    if [ -n "$expstart" ]; then 
	new "Check startup db content"
	expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><startup/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS>$expstart</rpc-reply>]]>]]>$"
    fi

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
}

# Compatible == all yang modules match
# runtest <mode> <expected running> <expected startup>
# This is really just that modstate is stripped from candidate and running if modstate is off
new "1. Run without CLICON_XMLDB_MODSTATE ensure no modstate in datastore"
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp compat-valid.xml startup_db)
runtest false startup '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>' '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>'

new "Verify no modstate in running"
expect="modules-state"
ret=$(sudo grep $expect $dir/running_db)
if [ -n "$ret" ]; then
    err "did not expect $expect" "$ret"
fi

new "2. Load compatible valid startup (all OK)"
# This is really just that modstate is used in candidate and running if modstate is on
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp compat-valid.xml startup_db)
runtest true startup '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>' '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>'

new "Verify modstate in running"
expect="modules-state"
ret=$(sudo grep $expect $dir/running_db)
if [ -z "$ret" ]; then
    err "Expected $expect" "$ret"
fi

new "3. Load compatible running valid running (rest of tests are startup)"
# Just test that a valid db survives start from running
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp compat-valid.xml running_db)
runtest true running '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>' ''
#'<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>'

new "4. Load non-compat valid startup"
# Just test that a valid db survives start from running
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp non-compat-valid.xml startup_db)
runtest true startup '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>' #'<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>'

new "5. Load non-compat invalid startup. Enter failsafe, startup invalid."
# A test that if a non-valid startup is encountered, validation fails and failsafe is entered
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp non-compat-invalid.xml startup_db)
runtest true startup '<data><a1 xmlns="urn:example:a">always work</a1></data>' # '<data><a0 xmlns="urn:example:a">old version</a0><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b><c xmlns="urn:example:c">bla bla</c></data>' # sorted

new "6. Load non-compat invalid running. Enter failsafe, startup invalid."
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp non-compat-invalid.xml running_db)
(cd $dir; cp non-compat-valid.xml startup_db) # XXX tmp
runtest true running '<data><a1 xmlns="urn:example:a">always work</a1></data>' ''

#'<data><a0 xmlns="urn:example:a">old version</a0><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b><c xmlns="urn:example:c">bla bla</c></data>'

new "7. Load compatible invalid startup."
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp compat-invalid.xml startup_db)
runtest true startup '<data><a1 xmlns="urn:example:a">always work</a1></data>' # '<data><a0 xmlns="urn:example:a">old version</a0><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b><c xmlns="urn:example:c">bla bla</c></data>' # sorted

# This testcase contains an error/exception of the clixon xml parser, and
# I cant track down the memory leakage.
if [ $valgrindtest -ne 2 ]; then
new "8. Load non-compat startup. Syntax fail, enter failsafe, startup invalid"
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp compat-err.xml startup_db)
runtest true startup '<data><a1 xmlns="urn:example:a">always work</a1></data>' '<rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Get startup datastore: xml_parse: line 14: syntax error: at or before: &lt;</error-message></rpc-error>'
fi # valgrindtest

rm -rf $dir

new "endtest"

unset ret

endtest

