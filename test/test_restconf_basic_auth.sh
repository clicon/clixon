#!/usr/bin/env bash
# Restconf basic authentication tests as implemented by main example
# Note this is not supported by core clixon: you need ca-auth callback implemented a la the example
# For auth-type=none and auth-type=user, 
# For auth-type=ssl-certs, See test_restconf.sh test_restconf_ssl_certs.sh
# native? and http only
# Use the following user settings:
#  1. none 
#  2. anonymous - the registered anonymous user
#  3. andy      - a well-known user
#  3. unknown   - unknown user
# Use NACM to return XML for different returns for anonymous and andy

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

if ! ${HAVE_HTTP1}; then
    echo "...skipped: Must run with http/1"
    rm -rf $dir
    if [ "$s" = $0 ]; then exit 0; else return 0; fi
fi

APPNAME=example

# Common NACM scripts
. ./nacm.sh

cfg=$dir/conf.xml

# The anonymous user
anonymous=myanonymous

fyang=$dir/myexample.yang

# No ssl

RCPROTO=http 
HVER=1.1

# Start with common config, then append fcgi/native specific config
# NOTE this is replaced in testrun()
cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_UPGRADE_CHECKOLD>true</CLICON_XMLDB_UPGRADE_CHECKOLD>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_ANONYMOUS_USER>$anonymous</CLICON_ANONYMOUS_USER>
</clixon-config>
EOF

# There are two implicit modules defined by RFC 8341
# This is a try to define them
cat <<EOF > $fyang
module myexample{
  yang-version 1.1;
  namespace "urn:example:auth";
  prefix ex;
  import ietf-netconf-acm {
        prefix nacm;
  }
  container top {
     leaf anonymous{
        type string;
     }     
     leaf wilma {
        type string;
     }
  }
}
EOF

# NACM rules and top/ config
cat <<EOF > $dir/startup_db
<${DATASTORE_TOP}>
   <nacm xmlns="urn:ietf:params:xml:ns:yang:ietf-netconf-acm">
     <enable-nacm>true</enable-nacm>
     <read-default>deny</read-default>
     <write-default>deny</write-default>
     <exec-default>deny</exec-default>
     <groups>
       <group>
         <name>anonymous</name>
         <user-name>$anonymous</user-name>
       </group>
       <group>
         <name>limited</name>
         <user-name>wilma</user-name>
       </group>
       <group>
         <name>admin</name>
         <user-name>root</user-name>
         $EXTRAUSER
       </group>
     </groups>
     <rule-list>
       <name>data-anon</name>
       <group>anonymous</group>
       <rule>
         <name>allow-get</name>
         <module-name>ietf-netconf</module-name>
         <rpc-name>get</rpc-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
       </rule>
       <rule>
         <name>allow-anon</name>
         <module-name>myexample</module-name>
         <access-operations>*</access-operations>
         <path xmlns:ex="urn:example:auth">/ex:top/ex:anonymous</path>
         <action>permit</action>
       </rule>
     </rule-list>       
     <rule-list>
       <name>data-limited</name>
       <group>limited</group>
       <rule>
         <name>allow-get</name>
         <module-name>ietf-netconf</module-name>
         <rpc-name>get</rpc-name>
         <access-operations>exec</access-operations>
         <action>permit</action>
       </rule>
       <rule>
         <name>allow-wilma</name>
         <module-name>myexample</module-name>
         <access-operations>*</access-operations>
         <path xmlns:ex="urn:example:auth">/ex:top/ex:wilma</path>
         <action>permit</action>
       </rule>
     </rule-list>

     $NADMIN

   </nacm>
   <top xmlns="urn:example:auth">
     <anonymous>42</anonymous>
     <wilma>71</wilma>
   </top>
</${DATASTORE_TOP}>
EOF

# Restconf auth test with arguments:
# 1. auth-type
# 2: -u user:passwd or ""
# 3: expectcode  expected HTTP return code
# 4: expectmsg   top return JSON message
# The return cases are: authentication permit/deny, authorization permit/deny
# We use authorization returns here only to verify we got the right user in authentication.
# Authentication ok/nok
#   permit: 200 or 403
#   deny:   401
# The user replies are:
#   $anonymous: {"myexample:top":{"anonymous":"42"}}
#   wilma: {"myexample:top":{"wilma":"71"}}
#   unknown: retval 403
function testrun()
{
    auth=$1  
    user=$2
    expectcode=$3
    expectmsg=$4

#    echo "auth:$auth"
#    echo "user:$user"
#    echo "expectcode:$expectcode"
#    echo "expectmsg:$expectmsg"
    
    # Change restconf configuration before start restconf daemon
    RESTCONFIG=$(restconf_config $auth false)
    if [ $? -ne 0 ]; then
        err1 "Error when generating certs"
    fi

    # Start with common config, then append fcgi/native specific config
    cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>ietf-netconf:startup</CLICON_FEATURE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_BACKEND_DIR>/usr/local/lib/$APPNAME/backend</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_REGEXP>example_backend.so$</CLICON_BACKEND_REGEXP>
  <CLICON_RESTCONF_DIR>/usr/local/lib/$APPNAME/restconf</CLICON_RESTCONF_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/run/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/run/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_NACM_MODE>internal</CLICON_NACM_MODE>
  <CLICON_ANONYMOUS_USER>$anonymous</CLICON_ANONYMOUS_USER>
  $RESTCONFIG
</clixon-config>
EOF

    if [ $RC -ne 0 ]; then
        new "kill old restconf daemon"
        stop_restconf_pre

        new "start restconf daemon"
        start_restconf -f $cfg
    fi

    new "wait restconf"
    wait_restconf
    
    new "curl $CURLOPTS $user -X GET $RCPROTO://localhost/restconf/data/myexample:top"
    expectpart "$(curl $CURLOPTS $user -X GET $RCPROTO://localhost/restconf/data/myexample:top)" 0 $expectcode "$expectmsg"

    if [ $RC -ne 0 ]; then
        new "Kill restconf daemon"
        stop_restconf
    fi
}

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    sudo pkill -f clixon_backend # to be sure
    
    new "start backend -s startup -f $cfg"
    start_backend -s startup -f $cfg
fi

new "wait backend"
wait_backend

MSGANON='{"myexample:top":{"anonymous":"42"}}'
MSGWILMA='{"myexample:top":{"wilma":"71"}}'
# Authentication failed:
MSGERR1='{"ietf-restconf:errors":{"error":{"error-type":"protocol","error-tag":"access-denied","error-severity":"error","error-message":"The requested URL was unauthorized"}}}'
# Authentication OK Authorization failed:
MSGERR2='{"ietf-restconf:errors":{"error":{"error-type":"application","error-tag":"access-denied","error-severity":"error","error-message":"default deny"}}}'

AUTH=none

new "auth-type=$AUTH no user"
testrun $AUTH "" "HTTP/$HPRE 200" "$MSGANON"          # OK - anonymous

new "auth-type=$AUTH anonymous"
testrun $AUTH "-u ${anonymous}:foo" "HTTP/$HVER 200" "$MSGANON" # OK - anonymous

new "auth-type=$AUTH wilma"
testrun $AUTH "-u wilma:bar" "HTTP/$HVER 200"    # OK - wilma

new "auth-type=$AUTH wilma wrong passwd"
testrun $AUTH "-u wilma:wrong" "HTTP/$HVER 200" "$MSGANON"  # OK - wilma

AUTH=user

new "auth-type=$AUTH no user"
testrun $AUTH "" "HTTP/$HVER 401" "$MSGERR1"                   # denied

new "auth-type=$AUTH anonymous"
testrun $AUTH "-u ${anonymous}:foo" "HTTP/$HVER 401" # denied

new "auth-type=$AUTH wilma"
testrun $AUTH "-u wilma:bar" "HTTP/$HVER 200" "$MSGWILMA"                 # OK - wilma

new "auth-type=$AUTH wilma wrong passwd"
testrun $AUTH "-u wilma:wrong" "HTTP/$HVER 401" "$MSGERR1"      # denied

new "auth-type=$AUTH unknown"
testrun $AUTH "-u unknown:any"  "HTTP/$HVER 401" "$MSGERR1"     # denied

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

# unset conditional parameters
unset RESTCONFIG1
unset MSGANON
unset MSGWILMA
unset MSGERR1
unset MSGERR2

rm -rf $dir

new "endtest"
endtest
