#!/usr/bin/env bash
# Test plugin reset functionality
# First go through all startup modes and modstate true/false and add a loopback XML
# in reset
# Then do the same with an outdated modstate requiring upgrade

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example
cfg=$dir/conf_yang.xml
fyang=$dir/example@2020-01-01.yang
changelog=$dir/changelog.xml # Module revision changelog

# Create configuration
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>/usr/local/etc/clixon.xml</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLI_MODE>hello</CLICON_CLI_MODE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/hello/clispec</CLICON_CLISPEC_DIR>
  <CLICON_SOCK>/usr/local/var/hello.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/hello.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_UPGRADE_CHECKOLD>false</CLICON_XMLDB_UPGRADE_CHECKOLD>
  <CLICON_XML_CHANGELOG>false</CLICON_XML_CHANGELOG>
  <CLICON_XML_CHANGELOG_FILE>$changelog</CLICON_XML_CHANGELOG_FILE>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example {
    yang-version 1.1;
    namespace "urn:example:clixon";
    prefix ex;
    revision 2020-01-01 {
        description
            "Clixon hello world example";
    }
    revision 2010-01-01 {
        description
            "Clixon hello world example";
    }
    container table{
        list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type string;
            }
        }
    }
}
EOF

cat <<EOF > $changelog
<changelogs xmlns="http://clicon.org/xml-changelog" xmlns:a="urn:example:a" xmlns:b="urn:example:b" >
  <changelog>
    <namespace>urn:example:clixon</namespace>
    <revfrom>2010-01-01</revfrom>
    <revision>2020-01-01</revision>
    <step>
      <name>rename foo to value</name>
      <op>rename</op>
      <where>/ex:table/ex:parameter/ex:foo</where>
      <tag>"value"</tag>
    </step>
  </changelog>
</changelogs>
EOF

# Start and stop backend with reset function that adds extraxml
# Args:
# 1: db       Startup db
# 2: mode     Startup mode (init, startup, running, none)
# 3: modstate true: Add yang-lib modstate to sytartup file
# 4: outdated true: Outdated modstate requires upgrade
function testrun()
{
    db=$1
    mode=$2
    modstate=$3
    outdated=$4

    if $outdated; then
        TAG=foo
        REV=2010-01-01
    else
        TAG=value
        REV=2020-01-01
    fi
    if [ -n "$db" ]; then
        sudo rm $dir/$db
        cat <<EOF > $dir/$db
<${DATASTORE_TOP}>
   <table xmlns="urn:example:clixon">
      <parameter>
         <name>x</name>
         <$TAG>42</$TAG>
      </parameter>
   </table>
EOF
        if $modstate; then
            cat <<EOF >> $dir/$db
   <yang-library xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <content-id>42</content-id>
      <module-set>
         <name>default</name>
         <module>
            <name>clixon-example</name>
            <revision>$REV</revision>
            <namespace>urn:example:clixon</namespace>
         </module>
      </module-set>
   </yang-library>
EOF
        fi
        cat <<EOF >> $dir/$db
</${DATASTORE_TOP}>  
EOF
    fi

    # Bring your own backend
    if [ $BE -ne 0 ]; then
        # kill old backend (if any)
        new "kill old backend"
        sudo clixon_backend -zf $cfg
        if [ $? -ne 0 ]; then
            err
        fi
        new "start backend -s $mode -f $cfg -o CLICON_XMLDB_MODSTATE=$modstate -o CLICON_XML_CHANGELOG=$outdated -- -r"
        start_backend -s $mode -f $cfg -o CLICON_XMLDB_MODSTATE=$modstate -o CLICON_XML_CHANGELOG=$outdated -- -r
    fi

    new "wait backend"
    wait_backend

    if [ -n "$db" ]; then
        XMLDB="<parameter><name>x</name><value>42</value></parameter>"
    else
        XMLDB=""
    fi
    XML="<rpc-reply $DEFAULTNS><data><table xmlns=\"urn:example:clixon\"><parameter><name>loopback</name><value>99</value></parameter>$XMLDB</table></data></rpc-reply>"
    
    new "get config"
    expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get><filter type=\"subtree\"><table xmlns=\"urn:example:clixon\"/></filter></get></rpc>" "" "$XML"

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

new "test params: -f $cfg"

new "Startup and modstate"
testrun startup_db startup true false

new "Startup and no modstate"
testrun startup_db startup false false

new "Running and modstate"
testrun running_db running true false

new "Running and no modstate"
testrun running_db running false false

new "Init and modstate"
testrun "" init true false

new "Init and no modstate"
testrun "" init false false

new "None and modstate"
testrun "" none true false

new "None and no modstate"
testrun "" none false false

new "Startup and old modstate"
testrun startup_db startup true true

new "Running and old modstate"
testrun running_db running true true

new "Init and old modstate"
testrun "" init true true

new "None and modstate"
testrun "" none true true

rm -rf $dir

new "endtest"
endtest
