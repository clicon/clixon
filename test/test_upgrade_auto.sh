#!/bin/bash
# Auto-upgrade using draft-wang-netmod-module-revision-management
# Ways of changes (operation-type) are:
# create, delete, move, modify
# In this example, example-a has the following changes:
# - Create y, delete x, replace host-name, move z
# example-b is completely obsoleted

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
changelog=$dir/changelog.xml # Module revision changelog
changelog2=$dir/changelog2.xml # From draft appendix
exa01y=$dir/example-a@2017-12-01.yang
exa20y=$dir/example-a@2017-12-20.yang
exb20y=$dir/example-b@2017-12-20.yang

# draft-wang-netmod-module-revision-management-01
# 3.2.1 and 4.1 example-a revision 2017-12-01
cat <<EOF > $exa01y
module example-a{
    yang-version 1.1;
    namespace "urn:example:a";
    prefix "a";

    organization "foo.";
    contact "fo@example.com";
    description
	"foo.";

    revision 2017-12-01 {
	description "Initial revision.";
    }

    container system {
	leaf a {
	    type string;
	    description "no change";
	}
	leaf b {
	    type string;
	    description "rename tag";
	}
	leaf x {
	    type string;
	    description "delete";
	}
	leaf host-name {
	    type uint32;
	    description "modify type";
	}
	leaf z {
	    description "move to alt";
	    type string;
	}
    }
    container alt {
    }
}
EOF
# 3.2.1 and 4.1 example-a revision 2017-12-20
cat <<EOF > $exa20y
module example-a {
    yang-version 1.1;
    namespace "urn:example:a";
    prefix "a";

    organization "foo.";
    contact "fo@example.com";
    description
	"foo.";

    revision 2017-12-20 {
	description "Create y, delete x, replace host-name, move z";
    }
    revision 2017-12-01 {
	description "Initial revision.";
    }
    container system {
	leaf a {
	    type string;
	    description "no change";
	}
	leaf c {
	    type string;
	    description "rename tag";
	}
	leaf host-name {
	    type string;
	    description "replace";
	}
	leaf y {
	    type string;
	    description "create";
	}
    }
    container alt {
	leaf z {
	    description "move to alt";
	    type string;
	}
    }
}
EOF

# 3.2.1 and 4.1 example-a revision 2017-12-20
cat <<EOF > $exb20y
module example-b {
    yang-version 1.1;
    namespace "urn:example:b";
    prefix "b";

    organization "foo.";
    contact "fo@example.com";
    description
	"foo.";

    revision 2017-12-20 {
	description "Remove all";
    }
}
EOF

# Create failsafe db
cat <<EOF > $dir/failsafe_db
<config>
  <system xmlns="urn:example:a">
    <a>Failsafe</a>
  </system>
</config>
EOF

# Create startup db revision example-a and example-b 2017-12-01
# this should be automatically upgraded to 2017-12-20
cat <<EOF > $dir/startup_db
<config>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>example-a</name>
         <revision>2017-12-01</revision>
         <namespace>urn:example:a</namespace>
      </module>
      <module>
         <name>example-b</name>
         <revision>2017-12-01</revision>
         <namespace>urn:example:b</namespace>
      </module>
  </modules-state>
  <system xmlns="urn:example:a">
    <a>dont change me</a>
    <b>rename me</b>
    <host-name>modify me</host-name>
    <x>remove me</x>
    <z>move me</z>
  </system>
  <alt xmlns="urn:example:a">
  </alt>
  <system-b xmlns="urn:example:b">
    <b>Obsolete</b>
  </system-b>
</config>
EOF

# Wanted new XML
XML='<system xmlns="urn:example:a"><a>dont change me</a><c>rename me</c><host-name>i am modified</host-name><y>created</y></system><alt xmlns="urn:example:a"><z>move me</z></alt>'


# Create configuration
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <CLICON_XML_CHANGELOG>true</CLICON_XML_CHANGELOG>
  <CLICON_XML_CHANGELOG_FILE>$changelog</CLICON_XML_CHANGELOG_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
</clixon-config>
EOF

# Changelog of example-a: 
cat <<EOF > $changelog
<changelogs xmlns="http://clicon.org/xml-changelog">
  <changelog>
    <namespace>urn:example:b</namespace>
    <revfrom>2017-12-01</revfrom>
    <revision>2017-12-20</revision>
    <step>
      <name>1</name>
      <op>delete</op>
      <where>/b:system-b</where>
    </step>
  </changelog>
  <changelog>
    <namespace>urn:example:a</namespace>
    <revfrom>2017-12-01</revfrom>
    <revision>2017-12-20</revision>
    <step>
      <name>0</name>
      <op>rename</op>
      <where>/a:system/a:b</where>
      <tag>"c"</tag>
    </step>
    <step>
      <name>1</name>
      <op>insert</op>
      <where>/a:system</where>
      <new><y>created</y></new>
    </step>
    <step>
      <name>2</name>
      <op>delete</op>
      <where>/a:system/a:x</where>
    </step>
    <step>
      <name>3</name>
      <op>replace</op>
      <where>/a:system/a:host-name</where>
      <new><host-name>i am modified</host-name></new>
    </step>
    <step>
      <name>4</name>
      <op>move</op>
      <where>/a:system/a:z</where>
      <dst>/a:alt</dst>
    </step>
  </changelog>
</changelogs>
EOF

# Start new system from old datastore
mode=startup

new "test params: -s $mode -f $cfg"
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
fi
new "waiting"
sleep $RCWAIT

new "kill old restconf daemon"
sudo pkill -u www-data clixon_restconf

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
sleep $RCWAIT

new "Check running db content"
expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><get-config><source><running/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$XML</data></rpc-reply>]]>]]>$"

new "Kill restconf daemon"
stop_restconf

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=`pgrep -u root -f clixon_backend`
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg

    rm -rf $dir
fi
