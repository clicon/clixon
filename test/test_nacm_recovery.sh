#!/usr/bin/env bash
# NACM recovery user and credentials for internal mode
# Use read-only NACM as use-case, ie to be able to break a deadlock and access
# the config even though NACM is enabled and write is DENY
# Only use netconf - restconf also has authentication on web level, and that gets
# another layer
# The only recovery session that work are: (last true arg to testrun)
#

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang

# cred:none, exact, except

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
RULES='<x xmlns="urn:example:nacm">0</x><nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm"><enable-nacm>true</enable-nacm><read-default>permit</read-default><write-default>permit</write-default><exec-default>permit</exec-default><enable-external-groups>true</enable-external-groups></nacm>'


DEFAULT='<nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm"><enable-nacm>true</enable-nacm><read-default>permit</read-default><write-default>deny</write-default><exec-default>permit</exec-default><enable-external-groups>true</enable-external-groups></nacm>'

# Arguments:
# cred:     none/exact/except
# realuser: sudo/su as user, this is the real "peer" user
# pseudo:   mimic/run as user, this is the one sent in XML
# recovery: recovery user
# getp:     true: get works; false: get does not work
# putp:     true: expected to work; false: not work
testrun()
{
    cred=$1
    realuser=$2
    pseudo=$3
    recovery=$4
    getp=$5
    putp=$6

    if [ "$realuser" = "root" ]; then
	prefix="sudo "
    else
	prefix=""
    fi
    
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_MODULE_LIBRARY_RFC7895>false</CLICON_MODULE_LIBRARY_RFC7895>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
  <CLICON_NACM_RECOVERY_USER>$recovery</CLICON_NACM_RECOVERY_USER>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_CREDENTIALS>$cred</CLICON_NACM_CREDENTIALS>
</clixon-config>
EOF
    if [ $BE -ne 0 ]; then
	sudo clixon_backend -zf $cfg
	if [ $? -ne 0 ]; then
	    err
	fi
	new "start backend -s init -f $cfg"
	start_backend -s init -f $cfg

	new "waiting"
	wait_backend
    fi
    if [ $RC -ne 0 ]; then
	new "kill old restconf daemon"
	stop_restconf_pre

	new "start restconf daemon (-a is enable basic authentication)"
	start_restconf -f $cfg -- -a

	new "waiting"
	wait_restconf
    fi

    if $getp; then
	# default is read allowed so this should always succeed.
	new "get startup default ok"
	expecteof "$prefix$clixon_netconf -qf $cfg -U $pseudo" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><data>$DEFAULT</data></rpc-reply>]]>]]>$"
	# This would normally not work except in recovery situations
    else
	new "get startup not ok"
	expecteof "$prefix$clixon_netconf -qf $cfg -U $pseudo" 0 "<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>User $realuser credential not matching NACM user $pseudo</error-message></rpc-error></rpc-reply>]]>]]>$"
	return;
    fi
	
    if $putp; then
	new "put, expect ok"
	expecteof "$prefix$clixon_netconf -qf $cfg -U $pseudo" 0 "<rpc><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "<rpc-reply><ok/></rpc-reply>]]>]]>"

	new "get rules ok"
	expecteof "$prefix$clixon_netconf -qf $cfg -U $pseudo" 0 '<rpc><get-config><source><candidate/></source></get-config></rpc>]]>]]>' "^<rpc-reply><data>$RULES</data></rpc-reply>]]>]]>$"
    else
	new "put, expect fail"
	expecteof "$prefix$clixon_netconf -qf $cfg -U $pseudo" 0 "<rpc><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>]]>]]>" "^<rpc-reply><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>default deny</error-message></rpc-error></rpc-reply>]]>]]>$"
    fi
    if [ $RC -ne 0 ]; then
	new "Kill restconf daemon"
	stop_restconf 
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

#------- REALUSER: $USER

# Neither of these should work: user != recovery
REALUSER=$USER
PSEUDO=$USER
RECOVERY=_recovery
for c in none exact except; do
    new "cred: $c realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
    testrun $c $REALUSER $PSEUDO $RECOVERY true false
done

# All these should work: user == recovery
REALUSER=$USER
PSEUDO=$USER
RECOVERY=$USER
for c in none exact except; do
    new "cred: $c realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
    testrun $c $REALUSER $PSEUDO $RECOVERY true true
done

# Only none credentials should work
REALUSER=$USER
PSEUDO=_recovery
RECOVERY=_recovery
new "cred: none realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun none $REALUSER $PSEUDO $RECOVERY true true
for c in exact except; do
    new "cred: $c realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
    testrun $c $REALUSER $PSEUDO $RECOVERY false false
done

# None of these work
REALUSER=$USER
PSEUDO=_recovery
RECOVERY=$USER
new "cred: none realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun none $REALUSER $PSEUDO $RECOVERY true false
for c in exact except; do
    new "cred: $c realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
    testrun $c $REALUSER $PSEUDO $RECOVERY false false
done

#------- REALUSER: ROOT
#XXX: seems not to work in docker
# Neither of these should work: user != recovery
REALUSER=root
PSEUDO=root
RECOVERY=_recovery
for c in none exact except; do
    new "cred: $c realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
    testrun $c $REALUSER $PSEUDO $RECOVERY true false
done

# All these should work: user == recovery
REALUSER=root
PSEUDO=root
RECOVERY=root
for c in none exact except; do
    new "cred: $c realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
    testrun $c $REALUSER $PSEUDO $RECOVERY true true
done

# none and except credentials should work
# XXX: except does not work in travis
REALUSER=root
PSEUDO=_recovery
RECOVERY=_recovery
for c in none except; do
    new "cred: $c realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
    testrun $c $REALUSER $PSEUDO $RECOVERY true true
done
new "cred: exact realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun exact $REALUSER $PSEUDO $RECOVERY false false

# None of these work
REALUSER=root
PSEUDO=_recovery
RECOVERY=root
for c in none except; do
    new "cred: $c realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
    testrun $c $REALUSER $PSEUDO $RECOVERY true false
done
new "cred: exact realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun exact $REALUSER $PSEUDO $RECOVERY false false

rm -rf $dir
