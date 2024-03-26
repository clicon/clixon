#!/usr/bin/env bash
# NACM recovery user and credentials for internal mode
# Use read-only NACM as use-case, ie to be able to break a deadlock and access
# the config even though NACM is enabled and write is DENY
# Only use netconf - restconf also has authentication on web level, and that gets
# another layer
# Main test default except mode, it gets too complicated otherwise
#

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf_yang.xml
fyang=$dir/nacm-example.yang

NACMUSER=$(whoami)

# cred:none, exact, except

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config user false)

cat <<EOF > $fyang
module nacm-example{
  yang-version 1.1;
  namespace "urn:example:nacm";
  prefix nex;
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
function testrun()
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
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
  <CLICON_YANG_LIBRARY>false</CLICON_YANG_LIBRARY>
  <CLICON_NACM_RECOVERY_USER>$recovery</CLICON_NACM_RECOVERY_USER>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_NACM_CREDENTIALS>$cred</CLICON_NACM_CREDENTIALS>
  $RESTCONFIG
</clixon-config>
EOF
    if [ $BE -ne 0 ]; then
        sudo clixon_backend -zf $cfg
        if [ $? -ne 0 ]; then
            err
        fi
        new "start backend -s init -f $cfg"
        start_backend -s init -f $cfg
    fi

    new "wait backend"
    wait_backend

    if [ $RC -ne 0 ]; then
        new "kill old restconf daemon"
        stop_restconf_pre

        new "start restconf daemon"
        start_restconf -f $cfg
    fi

    new "wait restconf"
    wait_restconf

    if $getp; then
        # default is read allowed so this should always succeed.
        new "get startup default ok"
        expecteof_netconf "$prefix$clixon_netconf -qf $cfg -U $pseudo" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source><with-defaults xmlns=\"urn:ietf:params:xml:ns:yang:ietf-netconf-with-defaults\">report-all</with-defaults></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data>$DEFAULT</data></rpc-reply>"
        # This would normally not work except in recovery situations
    else
        new "get startup not ok"
        expecteof_netconf "$prefix$clixon_netconf -qf $cfg -U $pseudo" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>User $realuser credential not matching NACM user $pseudo</error-message></rpc-error></rpc-reply>"
    fi
        
    if $putp; then
        new "put, expect ok"
        expecteof_netconf "$prefix$clixon_netconf -qf $cfg -U $pseudo" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>" "" "<rpc-reply $DEFAULTNS><ok/></rpc-reply>"

        new "get rules ok"
        expecteof_netconf "$prefix$clixon_netconf -qf $cfg -U $pseudo" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><get-config><source><candidate/></source></get-config></rpc>" "" "<rpc-reply $DEFAULTNS><data>$RULES</data></rpc-reply>"
    else
        new "put, expect fail"
        expecteof_netconf "$prefix$clixon_netconf -qf $cfg -U $pseudo" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><edit-config><target><candidate/></target><config>$RULES</config></edit-config></rpc>" "<rpc-reply $DEFAULTNS><rpc-error><error-type>application</error-type><error-tag>access-denied</error-tag><error-severity>error</error-severity><error-message>" "" # default deny</error-message></rpc-error></rpc-reply>"
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

#------- CRED: except USER: non-root
if [ "$NACMUSER" != root ]; then # Skip if USER is root
# This is default, therefore first
CRED=except 
REALUSER=$NACMUSER

# Recovery as a seperate user does not work
PSEUDO=$NACMUSER
RECOVERY=_recovery
new "cred: $CRED realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun $CRED $REALUSER $PSEUDO $RECOVERY true false

# Recovery as actual user works
PSEUDO=$NACMUSER
RECOVERY=$NACMUSER
new "cred: $CRED realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun $CRED $REALUSER $PSEUDO $RECOVERY true true

# pseudo-user as recovery user does not work if actual user is non-root/non-web
PSEUDO=_recovery
RECOVERY=_recovery
new "cred: $CRED realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun $CRED $REALUSER $PSEUDO $RECOVERY false false

PSEUDO=_recovery
RECOVERY=$NACMUSER
new "cred: $CRED realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun $CRED $REALUSER $PSEUDO $RECOVERY false false

fi # skip is NACMUSER is root

#------- CRED: except NACMUSER: root
CRED=except 
REALUSER=root 

# Recovery as a seperate user does not work
PSEUDO=root
RECOVERY=_recovery
new "cred: $CRED realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun $CRED $REALUSER $PSEUDO $RECOVERY true false

# Recovery as actual user works
PSEUDO=root
RECOVERY=root
new "cred: $CRED realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun $CRED $REALUSER $PSEUDO $RECOVERY true true

# pseudo-user as recovery user works IF cred=except AND realuser=root!
PSEUDO=_recovery
RECOVERY=_recovery
new "cred: $CRED realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun $CRED $REALUSER $PSEUDO $RECOVERY true true

PSEUDO=_recovery
RECOVERY=root
new "cred: $CRED realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun $CRED $REALUSER $PSEUDO $RECOVERY true false

#------- CRED: none
# Check you can use any pseudo user if cred is none
CRED=none
REALUSER=$NACMUSER
PSEUDO=_recovery
RECOVERY=_recovery
new "cred: $CRED realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun $CRED $REALUSER $PSEUDO $RECOVERY true true

#------- CRED: exact
# pseudo-user as recovery user does not work if cred=exact
CRED=exact
REALUSER=root
PSEUDO=_recovery
RECOVERY=_recovery
new "cred: $CRED realuser:$REALUSER pseudo:$PSEUDO recovery:$RECOVERY"
testrun $CRED $REALUSER $PSEUDO $RECOVERY false false

new "endtest"
endtest

unset NACMUSER

rm -rf $dir
