#!/bin/bash
# Starting clixon with outdated (or not) modules
# This relieas on storing RFC7895 YANG Module Library modules-state info
# in the datastore (or XML files?)
# There is also a: Factory default Setting:
#        draft-wu-netconf-restconf-factory-restore-03
# And: A YANG Data Model for module revision management:
#        draft-wang-netmod-module-revision-management-01
# The test is made with three Yang models A, B and C as follows:
# Yang module A has revisions "814-01-28" and "2019-01-01"
# Yang module B has only revision "2019-01-01"
# Yang module C has only revision "2019-01-01"
# The system is started YANG modules:
#      A revision "2019-01-01"
#      B revision "2019-01-01"
# The (startup) configuration XML file has:
#      A revision "814-01-28";
#      B revision "2019-01-01"
#      C revision "2019-01-01"
# Which means the following:
#      A has an obsolete version
#         containing a0 which has been removed, and a1 which is OK
#      B has a compatible version
#      C is not present in the system

APPNAME=example

# include err() and new() functions and creates $dir
. ./lib.sh

cfg=$dir/conf_yang.xml
fyangA0=$dir/A@814-01-28.yang
fyangA1=$dir/A@2019-01-01.yang
fyangB=$dir/B@2019-01-01.yang

# Yang module A revision "814-01-28"
# Note that this Yang model will exist in the DIR but will not be loaded
# by the system. Just here for reference
# XXX: Maybe it should be loaded and used in draft-wu?
cat <<EOF > $fyangA0
module A{
  prefix a;
  revision 814-01-28;
  namespace "urn:example:a";
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
  revision 2019-01-01;
  revision 814-01-28;
  namespace "urn:example:a";
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
  revision 2019-01-01;
  namespace "urn:example:b";
  leaf b{
    type string;
  }
}
EOF

# Yang module C revision "2019-01-01" (note not written to yang dir)
cat <<EOF > /dev/null
module C{
  prefix c;
  revision 2019-01-01;
  namespace "urn:example:c";
  leaf c{
    type string;
  }
}
EOF

# Create configuration
cat <<EOF > $cfg
<config>
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_PLUGIN>/usr/local/lib/xmldb/text.so</CLICON_XMLDB_PLUGIN>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
</config>
EOF

# Create failsafe db
cat <<EOF > $dir/failsafe_db
<config>
   <a1 xmlns="urn:example:a">always work</a1>
</config>
EOF

# Create compatible startup db
# startup config XML with following 
cat <<EOF > $dir/compat-valid.xml
<config>
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
</config>
EOF

# Create compatiblae startup db
# startup config XML with following 
cat <<EOF > $dir/compat-invalid.xml
<config>
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
</config>
EOF


# Create non-compat valid startup db
# startup config XML with following (A obsolete, B OK, C lacking)
# But XML is OK
cat <<EOF > $dir/non-compat-valid.xml
<config>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>814-01-28</revision>
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
</config>
EOF

# Create non-compat startup db
# startup config XML with following (A obsolete, B OK, C lacking)
cat <<EOF > $dir/non-compat-invalid.xml
<config>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>A</name>
         <revision>814-01-28</revision>
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
</config>
EOF

# Compatible startup with syntax errors
cat <<EOF > $dir/compat-err.xml
<config>
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
</config>
EOF

# Start system in $mode with existing (old) configuration in $db 
# mode is one of: init, none, running, or startup
# db is one of: running_db or startup_db
runtest(){
    mode=$1
    expect=$2
    startup=$3
    
    new "test params: -f $cfg"
    # Bring your own backend
    if [ $BE -ne 0 ]; then
	# kill old backend (if any)
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s $mode -f $cfg"
	start_backend -s $mode -f $cfg

	new "waiting"
	sleep $RCWAIT
    else
	new "Restart backend as eg follows: -Ff $cfg -s $mode ($BETIMEOUT s)"
	sleep $BETIMEOUT
    fi

    new "Get running"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' "^<rpc-reply>$expect</rpc-reply>]]>]]>$"

    new "Get startup"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><startup/></source></get-config></rpc>]]>]]>' "^<rpc-reply>$startup</rpc-reply>]]>]]>$"
    
    if [ $BE -ne 0 ]; then
	new "Kill backend"
	# Check if premature kill
	pid=`pgrep -u root -f clixon_backend`
	if [ -z "$pid" ]; then
	    err "backend already dead"
	fi
	# kill backend
	stop_backend -f $cfg
    fi
}

# Compatible == all yang modules match
# runtest <mode> <expected running> <expected startup>

new "1. Load compatible valid startup (all OK)"
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp compat-valid.xml startup_db)
runtest startup '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>' '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>'

new "2. Load compatible running valid running (rest of tests are startup)"
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp compat-valid.xml running_db)
runtest running '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>' '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>'

new "3. Load non-compat valid startup"
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp non-compat-valid.xml startup_db)
runtest startup '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>' '<data><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b></data>'

new "4. Load non-compat invalid startup. Enter failsafe, startup invalid."
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp non-compat-invalid.xml startup_db)
runtest startup '<data><a1 xmlns="urn:example:a">always work</a1></data>' '<data><a0 xmlns="urn:example:a">old version</a0><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b><c xmlns="urn:example:c">bla bla</c></data>'

new "5. Load non-compat invalid running. Enter failsafe, startup invalid."
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp non-compat-invalid.xml running_db)
runtest running '<data><a1 xmlns="urn:example:a">always work</a1></data>' '<data><a0 xmlns="urn:example:a">old version</a0><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b><c xmlns="urn:example:c">bla bla</c></data>'

new "6. Load compatible invalid startup."
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp compat-invalid.xml startup_db)
runtest startup '<data><a1 xmlns="urn:example:a">always work</a1></data>' '<data><a0 xmlns="urn:example:a">old version</a0><a1 xmlns="urn:example:a">always work</a1><b xmlns="urn:example:b">other text</b><c xmlns="urn:example:c">bla bla</c></data>'

# This testcase contains an error/exception of the clixon xml parser, and
# I cant track down the memory leakage.
if [ $valgrindtest -ne 2 ]; then
new "7. Load non-compat startup. Syntax fail, enter failsafe, startup invalid"
(cd $dir; rm -f tmp_db candidate_db running_db startup_db) # remove databases
(cd $dir; cp compat-err.xml startup_db)
runtest startup '<data><a1 xmlns="urn:example:a">always work</a1></data>' '<rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>read registry</error-message></rpc-error>'

fi

if [ $BE -ne 0 ]; then
    rm -rf $dir
fi
