#!/usr/bin/env bash
# Test quit startup after upgrade (-q) functionality
# The yang is from test_upgrade_interfaces and the upgrade code
# is implemented in the main example
# The test is just having 2014 xml syntax in file and the backend printing the upgraded
# syntax to stdout
# The output syntax is datastore syntax, as a running db would have looked like
# Note that the admin and stats field are non-config in the original, not here

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
if2014=$dir/interfaces@2014-05-08.yang
if2018=$dir/interfaces@2018-02-20.yang

# Create configuration
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_FEATURE>interfaces:if-mib</CLICON_FEATURE>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/example/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_MODSTATE>true</CLICON_XMLDB_MODSTATE>
  <CLICON_XMLDB_PRETTY>false</CLICON_XMLDB_PRETTY>
  <CLICON_XML_CHANGELOG>false</CLICON_XML_CHANGELOG>
  <CLICON_XMLDB_UPGRADE_CHECKOLD>true</CLICON_XMLDB_UPGRADE_CHECKOLD>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
</clixon-config>
EOF

# Original simplified version - note all is config to allow for storing in
# datastore
cat <<EOF > $if2014
module interfaces{
    yang-version 1.1;
    namespace "urn:example:interfaces";
    prefix "if";
    
    import ietf-yang-types {
	prefix yang;
    }
    revision 2014-05-08 {
	description
	    "Initial revision.";
	reference
	    "RFC 7223: A YANG Data Model for Interface Management";
    }
    feature if-mib {
	description
	    "This feature indicates that the device implements
       the IF-MIB.";
	reference
	    "RFC 2863: The Interfaces Group MIB";
    }
    leaf foo{
         description "Should not appear";
    	 type string;
	 default "bar";
    }
    container interfaces {
	description
	    "Interface configuration parameters.";

	list interface {
	    key "name";
	    leaf name {
		type string;
	    }
	    leaf description {
		type string;
	    }
            leaf foo{
              description "Should not appear";
              type string;
	      default "bar";
            }
	    leaf type {
		type string;
		mandatory true;
	    }
	    leaf link-up-down-trap-enable {
		if-feature if-mib;
		type enumeration {
		    enum enabled;
		    enum disabled;
		}
	    }
	}
    }
    container interfaces-state {
	list interface {
	    key "name";
	    leaf name {
		type string;
	    }
	    leaf admin-status {
		if-feature if-mib;
		type enumeration {
		    enum up;
		    enum down;
		    enum testing;
		}
		mandatory true;
	    }
	    container statistics {
		leaf in-octets {
		    type yang:counter64;
		}
		leaf in-unicast-pkts {
		    type yang:counter64;
		}
	    }
	}
    }
}

EOF

cat <<EOF > $if2018
module interfaces{
    yang-version 1.1;
    namespace "urn:example:interfaces";
    prefix "if";
    
    import ietf-yang-types {
	prefix yang;
    }
    revision 2018-02-20 {
     description
      "Updated to support NMDA.";
    reference
      "RFC 8343: A YANG Data Model for Interface Management";
    }
    revision 2014-05-08 {
	description
	    "Initial revision.";
	reference
	    "RFC 7223: A YANG Data Model for Interface Management";
    }
    feature if-mib {
	description
	    "This feature indicates that the device implements
       the IF-MIB.";
	reference
	    "RFC 2863: The Interfaces Group MIB";
    }
    leaf foo{
         description "Should not appear";
    	 type string;
	 default "fie";
    }
    container interfaces {
	description
	    "Interface configuration parameters.";

	list interface {
	    key "name";
	    leaf name {
		type string;
	    }
            leaf foo{
              description "Should not appear";
              type string;
	      default "bar";
            }
	    container docs{
               description "Original description is wrapped and renamed";
  	       leaf descr {
	 	 type string;
	       }
            }
	    leaf type {
		type string;
		mandatory true;
	    }
	    leaf link-up-down-trap-enable {
		if-feature if-mib;
		type enumeration {
		    enum enabled;
		    enum disabled;
		}
	    }
	    leaf admin-status {
		if-feature if-mib;
		type enumeration {
		    enum up;
		    enum down;
		    enum testing;
		}
		mandatory true;
	    }
	    container statistics {
		leaf in-octets {
		    type decimal64{
                       fraction-digits 3;
                    }
		}
		leaf in-unicast-pkts {
		    type yang:counter64;
		}
	    }
	}
    }
}
EOF

# Create startup db revision from 2014-05-08 to be upgraded to 2018-02-20
# This is 2014 syntax
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>interfaces</name>
         <revision>2014-05-08</revision>
         <namespace>urn:example:interfaces</namespace>
      </module>
  </modules-state>
  <interfaces xmlns="urn:example:interfaces">
    <interface>
      <name>e0</name>
      <type>eth</type>
      <description>First interface</description>
    </interface>
    <interface>
      <name>e1</name>
      <type>eth</type>
    </interface>
  </interfaces>
  <interfaces-state xmlns="urn:example:interfaces">
    <interface>
      <name>e0</name>
      <admin-status>up</admin-status>
      <statistics>
        <in-octets>54326432</in-octets>
        <in-unicast-pkts>8458765</in-unicast-pkts>
      </statistics>
    </interface>
    <interface>
      <name>e1</name>
      <admin-status>down</admin-status>
    </interface>
    <interface>
      <name>e2</name>
      <admin-status>testing</admin-status>
    </interface>
  </interfaces-state>
</${DATASTORE_TOP}>
EOF



# This is 2014 syntax
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>interfaces</name>
         <revision>2014-05-08</revision>
         <namespace>urn:example:interfaces</namespace>
      </module>
  </modules-state>
  <interfaces xmlns="urn:example:interfaces">
    <interface>
      <name>e0</name>
      <type>eth</type>
      <description>First interface</description>
    </interface>
    <interface>
      <name>e1</name>
      <type>eth</type>
    </interface>
  </interfaces>
  <interfaces-state xmlns="urn:example:interfaces">
    <interface>
      <name>e0</name>
      <admin-status>up</admin-status>
      <statistics>
        <in-octets>54326432</in-octets>
        <in-unicast-pkts>8458765</in-unicast-pkts>
      </statistics>
    </interface>
    <interface>
      <name>e1</name>
      <admin-status>down</admin-status>
    </interface>
    <interface>
      <name>e2</name>
      <admin-status>testing</admin-status>
    </interface>
  </interfaces-state>
</${DATASTORE_TOP}>
EOF

MODSTATE1="<modules-state xmlns=\"urn:ietf:params:xml:ns:yang:ietf-yang-library\"><module-set-id>0</module-set-id><module><name>clixon-lib</name><revision>${CLIXON_LIB_REV}</revision><namespace>http://clicon.org/lib</namespace></module>"

MODSTATE2='<module><name>interfaces</name><revision>2018-02-20</revision><namespace>urn:example:interfaces</namespace></module>'

XML='<interfaces xmlns="urn:example:interfaces"><interface><name>e0</name><docs><descr>First interface</descr></docs><type>eth</type><admin-status>up</admin-status><statistics><in-octets>54326.432</in-octets><in-unicast-pkts>8458765</in-unicast-pkts></statistics></interface><interface><name>e1</name><type>eth</type><admin-status>down</admin-status></interface></interfaces>'

ALL="<${DATASTORE_TOP}>$MODSTATE$XML</${DATASTORE_TOP}>"

# -u means trigger example upgrade

# kill old backend (if any)
new "kill old backend"
sudo clixon_backend -zf $cfg
if [ $? -ne 0 ]; then
    err
fi

new "start backend -s startup -f $cfg -q -- -u"
output=$(sudo $clixon_backend -F -D $DBG -s startup -f $cfg -q -- -u)

new "check modstate1"
match=$(echo "$output" | grep --null -o "$MODSTATE1")
if [ -z "$match" ]; then
    err "$MODSTATE1" "$output"
fi

new "check modstate"
match=$(echo "$output" | grep --null -o "$MODSTATE2")
if [ -z "$match" ]; then
    err "$MODSTATE2" "$output"
fi

new "check xml"
match=$(echo "$output" | grep --null -o "$XML")
if [ -z "$match" ]; then
    err "$XML" "$output"
fi

rm -rf $dir
new "endtest"
endtest

