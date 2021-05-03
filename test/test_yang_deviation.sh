#!/usr/bin/env bash
# Yang deviate tests
# See RFC 7950 5.6.3 and 7.20.3
# Four examples: not supported, add, replace, delete

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = "$0" ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyangbase=$dir/example-base.yang
fyangdev=$dir/example-deviations.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_DIR>$dir</CLICON_YANG_MAIN_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>true</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

cat <<EOF > $fyangbase
module example-base{
   yang-version 1.1;
   prefix base;
   namespace "urn:example:base";
   container system {
      must "daytime or time";
      leaf daytime{ 	    /* not supported removes this */
         type string;
      }
      list name-server {
         key name;
         leaf name {
            type string;
         } 
      }
      list user {
         key name;
         leaf name {
            type string;
         } 
         leaf type {
            type string;
	    /* add rule adds default here */
         } 
      }
   }
}
EOF

# Args:
# 0: daytime implemented: true/false
# 1: admin type default: true/false
function testrun()
{
    daytime=$1
    admindefault=$2
    
    new "test params: -f $cfg"

    if [ "$BE" -ne 0 ]; then
	new "kill old backend"
	sudo clixon_backend -zf "$cfg"
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s init -f $cfg"
	start_backend -s init -f "$cfg"
    fi

    new "wait backend"
    wait_backend

    if ! $daytime; then # Not supported - dont continue
	new "Add example-base daytime - should not be supported"
	expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:base\"><daytime>Sept17</daytime></system></config></edit-config></rpc>]]>]]>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>unknown-element</error-tag><error-info><bad-element>daytime</bad-element></error-info><error-severity>error</error-severity><error-message>Failed to find YANG spec of XML node: daytime with parent: system in namespace: urn:example:base</error-message></rpc-error></rpc-reply>]]>]]"
    else
	new "Add example-base daytime - supported"
	expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:base\"><daytime>Sept17</daytime></system></config></edit-config></rpc>]]>]]>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]"

	new "Add user bob"
	expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><system xmlns=\"urn:example:base\"><user><name>bob</name></user></system></config></edit-config></rpc>]]>]]>" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]"

	new "netconf commit"
	expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><commit/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"
	
	if $admindefault; then 
	    new "Get type admin expected"
	    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/base:system/base:user[base:name='bob']\" xmlns:base=\"urn:example:base\"/></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data><system xmlns=\"urn:example:base\"><user><name>bob</name><type>admin</type></user></system></data></rpc-reply>]]>]]>$"
# XXX Cannot select a default value??	    
#	    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/base:system/base:user[base:name='bob']/base:type\" xmlns:base=\"urn:example:base\"/></get-config></rpc>]]>]]>" foo
	else
	    new "Get type none expected"
	    expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><get-config><source><running/></source><filter type=\"xpath\" select=\"/base:system/base:user[base:name='bob']/base:type\" xmlns:base=\"urn:example:base\"/></get-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><data/></rpc-reply>]]>]]>$"
	fi
    fi
    if [ "$BE" -ne 0 ]; then
	new "Kill backend"
	# Check if premature kill
	pid=$(pgrep -u root -f clixon_backend)
	if [ -z "$pid" ]; then
	    err "backend already dead"
	fi
	# kill backend
	stop_backend -f "$cfg"
    fi
} # testrun

# Example from RFC 7950 Sec 7.20.3.3
cat <<EOF > $fyangdev
module example-deviations{
   yang-version 1.1;
   prefix md;
   namespace "urn:example:deviations";
   import example-base {
         prefix base;
   }
}
EOF
new "daytime supported"
testrun true false

# Example from RFC 7950 Sec 7.20.3.3
cat <<EOF > $fyangdev
module example-deviations{
   yang-version 1.1;
   prefix md;
   namespace "urn:example:deviations";
   import example-base {
         prefix base;
   }
   deviation /base:system/base:daytime {
      deviate not-supported;
   }
}
EOF
new "daytime not supported"
testrun false false

# Example from RFC 7950 Sec 7.20.3.3
cat <<EOF > $fyangdev
module example-deviations{
   yang-version 1.1;
   prefix md;
   namespace "urn:example:deviations";
   import example-base {
         prefix base;
   }
   deviation /base:system/base:user/base:type {
      deviate add {
         default "admin"; // new users are 'admin' by default
      }
   }
}
EOF
new "deviate add, check admin default"
testrun true true

rm -rf "$dir"

new "endtest"
endtest
