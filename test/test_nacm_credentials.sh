#!/usr/bin/env bash
# Test matching of Unix peer credentials with NACM users
# Use raw unix socket instead of clients (cli/netconf/restconf) since they do
# magic things with the username and here it needs to be handled explicitly.
# test matrix:
# - mode: none, exact, except
# - username: olof, admin, null, sudo
# - socket family: unix|ip

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Raw unit tester of backend unix socket.
: ${clixon_util_socket:=$(which clixon_util_socket)}

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang

cat <<EOF > $fyang
module nacm-example{
  yang-version 1.1;
  namespace "urn:example:nacm";
  prefix nex;
  import clixon-example {
	prefix ex;
  }
  import ietf-netconf-acm {
	prefix nacm;
  }
  leaf x{
    type int32;
    description "something to edit";
  }
}
EOF

# The groups are slightly modified from RFC8341 A.1
# The rule-list is from A.2
RULES=$(cat <<EOF
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>false</enable-nacm>
     <read-default>permit</read-default>
     <write-default>deny</write-default>
     <exec-default>deny</exec-default>

     $NGROUPS

     <rule-list>
       <name>guest-acl</name>
       <group>guest</group>
       <rule>
         <name>deny-ncm</name>
         <module-name>*</module-name>
         <access-operations>*</access-operations>
         <action>deny</action>
         <comment>
             Do not allow guests any access to the NETCONF
             monitoring information.
         </comment>
       </rule>
     </rule-list>
     <rule-list>
       <name>limited-acl</name>
       <group>limited</group>
       <rule>
         <name>permit-get</name>
         <rpc-name>get</rpc-name>
         <module-name>*</module-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
         <comment>
             Allow get 
         </comment>
       </rule>
       <rule>
         <name>permit-get-config</name>
         <rpc-name>get-config</rpc-name>
         <module-name>*</module-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
         <comment>
             Allow get-config
         </comment>
       </rule>
     </rule-list>

     $NADMIN

   </nacm>
   <x xmlns="urn:example:nacm">0</x>
EOF
)

# Set cred mode and run nacm operations
# Arguments:
# - mode (none,exact,except)
# - xml/nacm-username
# - socket family
# - socket file/addr
# - precommand /(eg sudo to raise to root)
testrun(){
    mode=$1
    username=$2
    family=$3
    sock=$4
    exp=$5
    precmd=$6
    
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_SOCK_FAMILY>$family</CLICON_SOCK_FAMILY>
  <CLICON_SOCK>$sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_DISABLED_ON_EMPTY>true</CLICON_NACM_DISABLED_ON_EMPTY>
  <CLICON_NACM_CREDENTIALS>$mode</CLICON_NACM_CREDENTIALS>
</clixon-config>
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
    
    new "waiting"
    wait_backend

    # First push in nacm rules via regular means
    new "auth set authentication config"
expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

    new "enable nacm"
    expecteof "$clixon_netconf -qf $cfg" 0 '<rpc><edit-config><target><candidate/></target><config><nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm"><enable-nacm>true</enable-nacm></nacm></config></edit-config></rpc>]]>]]>' "^<rpc-reply><ok/></rpc-reply>]]>]]>$" 

    new "commit it"
    expecteof "$clixon_netconf -qf $cfg" 0 "<rpc><commit/></rpc>]]>]]>" "^<rpc-reply><ok/></rpc-reply>]]>]]>$"

    #  raw socket test
    if [ -n "$username" ]; then
	XML="<rpc username=\"$username\"><get-config><source><running/></source><filter type=\"xpath\" select=\"/ex:x\" xmlns:ex=\"urn:example:nacm\"/></get-config></rpc>"
    else
	XML="<rpc><get-config><source><running/></source><filter type=\"xpath\" select=\"/ex:x\" xmlns:ex=\"urn:example:nacm\"/></get-config></rpc>"
    fi

    new "get-config mode:$mode user:$username $family $precmd"
    expecteof "$precmd $clixon_util_socket -a $family -s $sock -D $DBG" 0 "$XML" "$ex"
    
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

OK='^<rpc-reply><data><x xmlns="urn:example:nacm">0</x></data></rpc-reply>$'
ERROR='^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>'

# UNIX socket, no user, loop mode. All fail since null user cant access anything
new "Credentials: mode=none, fam=UNIX user=none"
testrun none "" UNIX $dir/backend.sock "$OK" ""

new "Credentials: mode=exact, fam=UNIX user=none"
testrun exact "" UNIX $dir/backend.sock "$OK" ""

new "Credentials: mode=except, fam=UNIX user=none"
testrun except "" UNIX $dir/backend.sock "$OK" ""

# UNIX socket, myuser, loop mode. All should work
new "Credentials: mode=none, fam=UNIX user=me"
testrun none "$USER" UNIX $dir/backend.sock "$OK" ""

new "Credentials: mode=exact, fam=UNIX user=me"
testrun exact "$USER" UNIX $dir/backend.sock "$OK" ""

new "Credentials: mode=except, fam=UNIX user=me"
testrun except "$USER" UNIX $dir/backend.sock "$OK" ""

# UNIX socket, admin user. First should work
new "Credentials: mode=none, fam=UNIX user=admin"
testrun none admin UNIX $dir/backend.sock "$OK" ""

new "Credentials: mode=exact, fam=UNIX user=admin"
testrun exact admin UNIX $dir/backend.sock "$ERROR" ""

new "Credentials: mode=except, fam=UNIX user=admin"
testrun except admin UNIX $dir/backend.sock "$ERROR" ""

# UNIX socket, admin user. sudo self to root. First and last should work
new "Credentials: mode=none, fam=UNIX user=admin sudo"
testrun none admin UNIX $dir/backend.sock "$OK" sudo

new "Credentials: mode=exact, fam=UNIX user=admin sudo"
testrun exact admin UNIX $dir/backend.sock "$ERROR" sudo

new "Credentials: mode=except, fam=UNIX user=admin sudo"
testrun except admin UNIX $dir/backend.sock "$OK" sudo

# IPv4 socket, admin user. First should work
new "Credentials: mode=none, fam=UNIX user=admin sudo"
testrun none $USER IPv4 127.0.0.1 "$OK" ""

new "Credentials: mode=exact, fam=UNIX user=admin sudo"
testrun exact $USER IPv4 127.0.0.1 "$ERROR" ""

new "Credentials: mode=except, fam=UNIX user=admin sudo"
testrun except $USER IPv4 127.0.0.1 "$ERROR" ""

rm -rf $dir

# unset conditional parameters 
unset clixon_util_socket
