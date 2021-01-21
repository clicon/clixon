#!/usr/bin/env bash
# Advanced Client api test
# Compile and run a client

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example-client.yang
cfile=$dir/example-client.c
pdir=$dir/plugin
app=$pdir/example-api

if [ ! -d $pdir ]; then
    mkdir $pdir
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>/usr/local/share/clixon</CLICON_YANG_DIR>
  <CLICON_YANG_DIR>$IETFRFC</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_RESTCONF_PRETTY>false</CLICON_RESTCONF_PRETTY>
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
#include <sys/socket.h>
#include <netinet/in.h> /* sockaddr_in */
#include <arpa/inet.h>  /* inet_addr */
#include <clixon/clixon_client.h>

#define CLIXONCONF "$cfg"

int
main(int    argc,
     char **argv)
{
    int   s;
    void *h = NULL; /* clixon handle */

    if ((h = clixon_client_init("server", stderr, 0, CLIXONCONF)) == NULL)
       return -1;
    if ((s = clixon_client_connect(h)) < 0){
       return -1;
    }
    /* Here are read functions depending on an example YANG 
     * (Need an example YANG and XML input to confd)
     */
    {
       uint32_t u = 0;
       if (clixon_client_get_uint32(s, &u, "urn:example:clixon-client", "/table/parameter[name='a']/value") < 0)
          return -1;
    }
    clixon_client_close(s);
    clixon_client_terminate(h);
    return 0;
}
EOF

new "compile $cfile -> $app"
echo "$CC -g -Wall -I/usr/local/include $cfile -o $app -lclixon"
expectpart "$($CC -g -Wall -I/usr/local/include $cfile -o $app -lclixon)" 0 ""
exit
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

new "waiting"
wait_backend

if [ $RC -ne 0 ]; then
    new "kill old restconf daemon"
    stop_restconf_pre

    new "start restconf daemon"
    start_restconf -f $cfg

    new "waiting"
    wait_restconf
fi

XML='<c xmlns="urn:example:api"><y3><k>2</k></y3><y3><k>3</k></y3><y3><k>5</k><val>zorro</val></y3><y3><k>7</k></y3></c>'

# Add a set of entries using restconf
new "PUT a set of entries"
expectpart "$(curl $CURLOPTS -X PUT -H 'Content-Type: application/yang-data+xml' $RCPROTO://localhost/restconf/data/example-api:c -d "$XML")" 0 "HTTP/1.1 201 Created"

new "Check entries"
expectpart "$(curl $CURLOPTS -X GET $RCPROTO://localhost/restconf/data/example-api:c -H 'Accept: application/yang-data+xml')" 0 'HTTP/1.1 200 OK' "$XML"

new "Send a trigger"
expectpart "$(curl $CURLOPTS -X POST $RCPROTO://localhost/restconf/operations/example-api:trigger -H 'Accept: application/yang-data+json')" 0 'HTTP/1.1 204 No Content'

if [ $RC -ne 0 ]; then
    new "Kill restconf daemon"
    stop_restconf
fi

if [ $BE -eq 0 ]; then
    exit # BE
fi

new "Kill backend"
# Check if premature kill
pid=`pgrep -u root -f clixon_backend`
if [ -z "$pid" ]; then
    err "backend already dead"
fi
# kill backend
stop_backend -f $cfg

# unset conditional parameters 
unset format

rm -rf $dir
