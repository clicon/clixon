#!/usr/bin/env bash
# Upgrade a module by registering a manually programmed callback
# The usecase is inspired by the ietf-interfaces upgrade from
# 2014-05-08 to 2018-02-20.
# That includes moving parts from interfaces-state to interfaces and then
# deprecating the whole /interfaces-state tree.
# A preliminary change list is in Appendix A of
# draft-wang-netmod-module-revision-management-01
# The example here is simplified and also extended.
# For exampe  admin and stats field are non-config in the original, not here
# It has also been broken up into two parts to test a series of upgrades.
# These are the operations (authentic move/delete are from ietf-interfaces):
# Move /if:interfaces-state/if:interface/if:admin-status to (2016)
#   /if:interfaces/if:interface/
# Move /if:interfaces-state/if:interface/if:statistics to (2016)
#   if:interfaces/if:interface/
# Delete /if:interfaces-state (2018)
# Rename /interfaces/interface/description to /interfaces/interface/descr (2016)
# Wrap /interfaces/interface/descr to /interfaces/interface/docs/descr (2018)
# Change type /interfaces/interface/statistics/in-octets to decimal64 and divide all values with 1000 (2018)
# 

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf.xml
if2014=$dir/interfaces@2014-05-08.yang
if2018=$dir/interfaces@2018-02-20.yang

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
    container interfaces {
	description
	    "Interface configuration parameters.";

	list interface {
	    key "name";
	    leaf name {
		type string;
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
  <CLICON_XML_CHANGELOG>false</CLICON_XML_CHANGELOG>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
</clixon-config>
EOF

# Start from startup and upgrade, check running 
function testrun(){
    runxml=$1 

    # -u means trigger example upgrade
    new "test params: -s startup -f $cfg -- -u"
    # Bring your own backend
    if [ $BE -ne 0 ]; then
	# kill old backend (if any)
	new "kill old backend"
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s startup -f $cfg -- -u"
	start_backend -s startup -f $cfg -- -u
    fi

    new "waiting"
    wait_backend
    
    new "Check running db content"
    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><running/></source></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data>$runxml</data></rpc-reply>]]>]]>$"

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

XML='<interfaces xmlns="urn:example:interfaces"><interface><name>e0</name><docs><descr>First interface</descr></docs><type>eth</type><admin-status>up</admin-status><statistics><in-octets>54326.432</in-octets><in-unicast-pkts>8458765</in-unicast-pkts></statistics></interface><interface><name>e1</name><type>eth</type><admin-status>down</admin-status></interface></interfaces>'

new "1. Upgrade from 2014 to 2018-02-20"
testrun "$XML"

# This is "2016" syntax
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
   <modules-state xmlns="urn:ietf:params:xml:ns:yang:ietf-yang-library">
      <module-set-id>42</module-set-id>
      <module>
         <name>interfaces</name>
         <revision>2016-01-01</revision>
         <namespace>urn:example:interfaces</namespace>
      </module>
  </modules-state>
  <interfaces xmlns="urn:example:interfaces">
    <interface>
      <name>e0</name>
      <admin-status>up</admin-status>
      <type>eth</type>
      <descr>First interface</descr>
      <statistics>
        <in-octets>54326432</in-octets>
        <in-unicast-pkts>8458765</in-unicast-pkts>
      </statistics>
    </interface>
    <interface>
      <name>e1</name>
      <type>eth</type>
      <admin-status>down</admin-status>
    </interface>
  </interfaces>
  <interfaces-state xmlns="urn:example:interfaces">
    <interface>
      <name>e0</name>
      <admin-status>down</admin-status>
      <statistics>
        <in-octets>946743234</in-octets>
        <in-unicast-pkts>218347</in-unicast-pkts>
      </statistics>
    </interface>
    <interface>
      <name>e1</name>
      <admin-status>up</admin-status>
    </interface>
    <interface>
      <name>e2</name>
      <admin-status>testing</admin-status>
    </interface>
  </interfaces-state>
</${DATASTORE_TOP}>
EOF

# 2. Upgrade from intermediate 2016-01-01 to 2018-02-20
new "2. Upgrade from intermediate 2016-01-01 to 2018-02-20"
testrun "$XML"

# Again 2014 syntax
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
rm $if2018
# Original XML
XML='<interfaces xmlns="urn:example:interfaces"><interface><name>e0</name><description>First interface</description><type>eth</type></interface><interface><name>e1</name><type>eth</type></interface></interfaces><interfaces-state xmlns="urn:example:interfaces"><interface><name>e0</name><admin-status>up</admin-status><statistics><in-octets>54326432</in-octets><in-unicast-pkts>8458765</in-unicast-pkts></statistics></interface><interface><name>e1</name><admin-status>down</admin-status></interface><interface><name>e2</name><admin-status>testing</admin-status></interface></interfaces-state>'

new "3. No 2018 (upgrade) model -> dont trigger upgrade"
testrun "$XML"

#rm $if2014
#new "4. No model at all"
#testrun "$XML"

rm -rf $dir

new "endtest"
endtest


