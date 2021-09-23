#!/usr/bin/env bash
# test xpath functions in YANG conditionals
# XPATH base https://www.w3.org/TR/xpath-10/
# YANG XPATH functions: https://tools.ietf.org/html/rfc7950
# Tests:
# - Contains

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/$APPNAME.yang

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$dir</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_NETCONF_DIR>/usr/local/lib/$APPNAME/netconf</CLICON_NETCONF_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
</clixon-config>
EOF

cat <<EOF > $fyang
module $APPNAME{
   yang-version 1.1;
   prefix ex;
   namespace "urn:example:clixon";
   identity interface-type;

   identity atm {
      base interface-type;
   }
   identity ethernet {
      base interface-type;
   }
   identity fast-ethernet {
      base ethernet;
   }
   identity gigabit-ethernet {
      base ethernet;
   }

   container top{ 
      leaf class { /* contains */
         type string;
      }
      list mylist{ /* contains */
         key id;
         leaf id {
 	    type string;
	 }
 	 leaf site {
	   /* If the XPath expression is defined in a substatement to a data
 	    * node that represents configuration, the accessible tree is the
 	    * data in the datastore where the context node exists.
	    * The "when" statement makes its parent data definition statement conditional.
 	    */
	    when "contains(../../class,'foo') or contains(../../class,'bar')";
 	    type int32;
         }
      }
   }
   list interface {  /* derived-from */
      key name;
      leaf name{
         type string;
      }
      leaf type {
         type identityref {
            base interface-type;
         }
      }
   }
   augment "/ex:interface" {
      when 'derived-from(type, "ex:ethernet")';
      leaf mtu {
         type uint32;
      }	 
   }
   augment "/ex:interface" {
      when 'derived-from-or-self(type, "ex:ethernet")';
      leaf crc {
         type uint32;
      }	 
   }
}
EOF

new "test params: -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend -s init -f $cfg"
    start_backend -s init -f $cfg
fi

new "wait backend"
wait_backend

# contains
new "contains: Set site to foo that validates site OK"
expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><class>foo</class><mylist><id>12</id><site>42</site></mylist></top></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

new "netconf validate OK"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Set site to fie which invalidates the when contains"
expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><top xmlns=\"urn:example:clixon\"><class>fie</class></top></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

new "netconf validate not OK"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Failed WHEN condition of site in module example (WHEN xpath is contains(../../class,'foo') or contains(../../class,'bar'))</error-message></rpc-error></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# derived-from
new "derived-from: Set mtu to interface OK on GE"
expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interface xmlns=\"urn:example:clixon\"><name>e0</name><type>fast-ethernet</type><mtu>1500</mtu></interface></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

new "netconf validate OK"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Change type to atm"
expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interface xmlns=\"urn:example:clixon\"><name>e0</name><type>atm</type></interface></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

new "netconf validate not OK (mtu not allowed)"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Failed WHEN condition of mtu in module example (WHEN xpath is derived-from(type, \"ex:ethernet\"))</error-message></rpc-error></rpc-reply>]]>]]>$"

new "Change type to ethernet (self)"
expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interface xmlns=\"urn:example:clixon\"><name>e0</name><type>ethernet</type></interface></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

new "netconf validate not OK (mtu not allowed on self)"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Failed WHEN condition of mtu in module example (WHEN xpath is derived-from(type, \"ex:ethernet\"))</error-message></rpc-error></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

# derived-from-or-self
new "derived-from-or-self: Set crc to interface OK on GE"
expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interface xmlns=\"urn:example:clixon\"><name>e0</name><type>fast-ethernet</type><crc>42</crc></interface></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

new "netconf validate OK"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "Change type to atm"
expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interface xmlns=\"urn:example:clixon\"><name>e0</name><type>atm</type></interface></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

new "netconf validate not OK (crc not allowed)"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>operation-failed</error-tag><error-severity>error</error-severity><error-message>Failed WHEN condition of crc in module example (WHEN xpath is derived-from-or-self(type, \"ex:ethernet\"))</error-message></rpc-error></rpc-reply>]]>]]>$"

new "Change type to ethernet (self)"
expecteof "$clixon_netconf -qf $cfg -D $DBG" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><edit-config><target><candidate/></target><config><interface xmlns=\"urn:example:clixon\"><name>e0</name><type>ethernet</type></interface></config></edit-config></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>"

new "netconf validate OK (self)"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><validate><source><candidate/></source></validate></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

new "netconf discard-changes"
expecteof "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO<rpc $DEFAULTNS><discard-changes/></rpc>]]>]]>" "^<rpc-reply $DEFAULTNS><ok/></rpc-reply>]]>]]>$"

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=$(pgrep -u root -f clixon_backend)
    if [ -z "$pid" ]; then
	err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
    sudo pkill -u root -f clixon_backend
fi

rm -rf $dir

new "endtest"
endtest
