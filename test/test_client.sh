#!/usr/bin/env bash
# Advanced Client api test
# Compile and run a client
# INSTALLFLSAGS="" 
# Why test only over external NETCONF? ie CLIXON_CLIENT_NETCONF
# there is also     CLIXON_CLIENT_IPC,      /* Internal IPC API, only experimental use */
#                   CLIXON_CLIENT_SSH       /* NYI External Netconf over SSH */

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example-client.yang
cfile=$dir/example-client.c
pdir=$dir/plugin
app=$dir/clixon-app
debug=0

if [ ! -d $pdir ]; then
    mkdir $pdir
fi

# Define default restconfig config: RESTCONFIG
RESTCONFIG=$(restconf_config none false)

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_FEATURE>clixon-restconf:allow-auth-none</CLICON_FEATURE> <!-- Use auth-type=none -->
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_DIR>$pdir</CLICON_BACKEND_DIR>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>$dir</CLICON_XMLDB_DIR>
  <CLICON_XMLDB_FORMAT>$format</CLICON_XMLDB_FORMAT>
  $RESTCONFIG
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-client {
    yang-version 1.1;
    namespace "urn:example:clixon-client";
    prefix exc;
    description
        "Clixon client example yang";
    revision 2021-01-14 {
        description "Added table/paramater/value as the primary data example";
    }
    /* Generic config data */
    container table{
      list parameter{
            key name;
            leaf name{
                type string;
            }
            leaf value{
                type uint32;
            }
        }
    }
}
EOF

cat<<EOF > $cfile
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <syslog.h> // debug

#include <clixon/clixon_log.h> // debug
#include <clixon/clixon_client.h>

int
main(int    argc,
     char **argv)
{
    int retval = -1;
    clixon_handle        h = NULL; /* clixon handle */
    clixon_client_handle ch = NULL; /* clixon client handle */
    int                  s;

    clicon_log_init("client", LOG_DEBUG, CLICON_LOG_STDERR);  // debug
    clicon_debug_init($debug, NULL);                          // debug

    /* Provide a clixon config-file, get a clixon handle */
    if ((h = clixon_client_init("$cfg")) == NULL)
       return -1;
    /* Make a connection over netconf or ssh/netconf */
    if ((ch = clixon_client_connect(h, CLIXON_CLIENT_NETCONF, NULL)) == NULL)
       return -1;
    s = clixon_client_socket_get(ch);
    if (clixon_client_hello(s, 0) < 0)
      return -1;
    /* Here are read functions depending on an example YANG 
     * (Need an example YANG and XML input to confd)
     */
    {
       uint32_t u = 0;
       if (clixon_client_get_uint32(ch, &u, "urn:example:clixon-client", "/table/parameter[name='a']/value") < 0)
         goto done;
       printf("%u\n", u); /* for test output */
    }
    retval = 0;
  done:
    clixon_client_disconnect(ch);
    clixon_client_terminate(h);
    printf("done\n"); /* for test output */     
    return retval;
}
EOF

new "compile $cfile -> $app"
if [ "$LINKAGE" = static ]; then
    COMPILE="$CC ${CFLAGS} -I/usr/local/include $cfile -o $app /usr/local/lib/libclixon${LIBSTATIC_SUFFIX} ${LIBS}"
else
    COMPILE="$CC ${CFLAGS} -I/usr/local/include $cfile -o $app -L /usr/local/lib -lclixon"
fi

echo "COMPILE:$COMPILE"
expectpart "$($COMPILE)" 0 ""

new "test params: -s init -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
        err
    fi
    new "start backend"
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

XML='<table xmlns="urn:example:clixon-client"><parameter><name>a</name><value>42</value></parameter></table>'

# Add a set of entries using restconf
new "POST the XML"
expectpart "$(curl $CURLOPTS -X POST -H 'Content-Type: application/yang-data+xml' $RCPROTO://localhost/restconf/data -d "$XML")" 0 "HTTP/$HVER 201"

new "Check entries"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/clixon-client:table -H 'Accept: application/yang-data+xml')" 0 "HTTP/$HVER 200" "$XML"

new "Run $app"
expectpart "$($app)" 0 '^42$'

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

if [ $BE -ne 0 ]; then
    new "Kill backend"
    # Check if premature kill
    pid=`pgrep -u root -f clixon_backend`
    if [ -z "$pid" ]; then
        err "backend already dead"
    fi
    # kill backend
    stop_backend -f $cfg
fi

rm -rf $dir

new "endtest"
endtest
