#!/bin/bash
# Order test. test ordered-by user and ordered-by system.
# For each leaf and leaf-lists, there are two lists,
# one ordered-by user and one ordered by system.
# The ordered-by user MUST be the order it is entered.
# No test of ordered-by system is done yet
# (we may want to sort them alphabetically for better performance).
# Also: ordered-by-user and "insert" and "key"/"value" attributes

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

APPNAME=example


cfg=$dir/conf_yang.xml
fyang=$dir/example-order.yang
cfile=$dir/example-order.c
pdir=$dir/plugin
sofile=$pdir/example-order.so

if [ ! -d $pdir ]; then
    mkdir $pdir
fi

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>/tmp/conf_yang.xml</CLICON_CONFIGFILE>
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
</clixon-config>
EOF

cat <<EOF > $fyang
module example-order{
    yang-version 1.1;
    namespace "urn:example:order";
    prefix ex;
    container c {
      leaf-list y0 {
        ordered-by user;
        type string;
      }
      leaf-list y1 {
        ordered-by system;
        type string;
      }
      list y2 {
        ordered-by user;
        key "k";
        leaf k {
          type int32;
        }
        leaf val {
          type string;
        }   
      }
      list y3 {
        ordered-by system;
        key "k";
        leaf k {
          type int32;
        }
        leaf val {
          type string;
        } 
      }
    }
    rpc trigger {
	description "trigger an action in the backend";
    }
}
EOF

cat<<EOF > $cfile
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/syslog.h>

/* clicon */
#include <cligen/cligen.h>

/* Clicon library functions. */
#include <clixon/clixon.h>

/* These include signatures for plugin and transaction callbacks. */
#include <clixon/clixon_backend.h> 

static int 
trigger_rpc(clicon_handle h,          /* Clicon handle */
	  cxobj        *xe,           /* Request: <rpc><xn></rpc> */
	  cbuf         *cbret,        /* Reply eg <rpc-reply>... */
	  void         *arg,          /* client_entry */
	  void         *regarg)       /* Argument given at register */
{
    int retval = -1;
    cxobj *xret = NULL;
    cxobj *xc = NULL;
    cxobj *x = NULL;
    char  *k; 
    char  *val;

    if (xmldb_get(h, "running", "/c", &xret) < 0)
      goto done;
    clicon_debug(1, "%s xret:%s", __FUNCTION__, xml_name(xret));
    xc = xpath_first(xret, "/c");
    clicon_debug(1, "%s xc:%s", __FUNCTION__, xml_name(xc));

    /* Method 1 loop */
    x = NULL;
    val = NULL;
    while ((x = xml_child_each(xc, x, -1)) != NULL) {
       if (strcmp(xml_name(x), "y3") != 0)
         continue;
       if ((k = xml_find_body(x, "k")) != NULL &&
           strcmp(k, "5") == 0){
          val = xml_find_body(x, "val");
          break;
       }
    }
    clicon_debug(1, "%s Method 1: val:%s", __FUNCTION__, val?val:"null");

    /* Method 2 xpath */
    val = NULL;
    if ((x = xpath_first(xc, "y3[k=5]")) != NULL)
       val = xml_find_body(x, "val");
    clicon_debug(1, "%s Method 2: val:%s", __FUNCTION__, val?val:"null");

    /* Method 3 binsearch */
    val = NULL;
    if ((x = xml_binsearch(xc, "y3", "k", "5")) != NULL)
       val = xml_find_body(x, "val");
    clicon_debug(1, "%s Method 3: val:%s", __FUNCTION__, val?val:"null");

    cprintf(cbret, "<rpc-reply><ok/></rpc-reply>");
    retval = 0;
  done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
//    if (xret)
  //     xml_free(xret);
    return retval;
}

clixon_plugin_api *clixon_plugin_init(clicon_handle h);

static clixon_plugin_api api = {
    "order",             /* name */           /*--- Common fields.  ---*/
    clixon_plugin_init, /* init */
};

/*! Backend plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    clicon_debug(1, "%s test-order", __FUNCTION__);

    /* From example.yang (clicon) */
    if (rpc_callback_register(h, trigger_rpc, 
			      NULL, 
			      "urn:example:order",
			      "trigger"/* Xml tag when callback is made */
			      ) < 0)
	return NULL;
    return &api;
}

EOF

new "compile $cfile"
gcc -Wall -rdynamic -fPIC -shared $cfile -o $sofile

new "test params: -s running -f $cfg"

if [ $BE -ne 0 ]; then
    new "kill old backend"
    sudo clixon_backend -zf $cfg
    if [ $? -ne 0 ]; then
	err
    fi
    new "start backend"
    start_backend -s running -f $cfg

fi

new "kill old restconf daemon"
sudo pkill -u www-data -f "/www-data/clixon_restconf"

new "start restconf daemon"
start_restconf -f $cfg

new "waiting"
wait_backend
wait_restconf

XML='<c xmlns="urn:example:order"><y3><k>2</k></y3><y3><k>3</k></y3><y3><k>5</k><val>zorro</val></y3><y3><k>7</k></y3></c>'

# Add a set of entries using restconf
new "PUT a set of entries"
expectpart "$(curl -si -X PUT -H 'Content-Type: application/yang-data+xml' http://localhost/restconf/data/example-order:c -d "$XML")" 0 "HTTP/1.1 201 Created"

new "Check entries"
expectpart "$(curl -si -X GET http://localhost/restconf/data/example-order:c -H 'Accept: application/yang-data+xml')" 0 'HTTP/1.1 200 OK' "$XML"

new "Send a trigger"
expectpart "$(curl -si -X POST http://localhost/restconf/operations/example-order:trigger -H 'Accept: application/yang-data+json')" 0 'HTTP/1.1 204 No Content'

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

rm -rf $dir
