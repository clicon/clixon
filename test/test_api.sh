#!/bin/bash
# Advanced API XML test. Compile a backend plugin and start the backend, and then send an RPC to
# trigger that plugin
# The plugin looks in an XML tree using three different methods:
# 1. xml_each and xml_find
# 2. xpath_first
# 3. binary_search

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

# Which format to use as datastore format internally
: ${format:=xml}

APPNAME=example

cfg=$dir/conf_yang.xml
fyang=$dir/example-api.yang
cfile=$dir/example-api.c
pdir=$dir/plugin
sofile=$pdir/example-api.so

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
module example-api{
    yang-version 1.1;
    namespace "urn:example:api";
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
    int        retval = -1;
    cxobj     *xret = NULL;
    cxobj     *xc = NULL;
    cxobj     *x = NULL;
    char      *k; 
    char      *val;
    cvec      *cvk = NULL;
    cg_var    *cv;
    cxobj    **xvec = NULL;
    size_t     xlen = 0;

    if (xmldb_get(h, "running", NULL, "/c", &xret) < 0)
      goto done;
    clicon_debug(1, "%s xret:%s", __FUNCTION__, xml_name(xret));
    xc = xpath_first(xret, NULL, "/c");
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
    if ((x = xpath_first(xc, NULL, "y3[k=5]")) != NULL)
       val = xml_find_body(x, "val");
    clicon_debug(1, "%s Method 2: val:%s", __FUNCTION__, val?val:"null");

    /* Method 3 binsearch */
    val = NULL;
    /* Add key/value vector */
    if ((cvk = cvec_new(0)) == NULL){
	clicon_err(OE_YANG, errno, "cvec_new");	
	goto done;
    }
    if ((cv = cvec_add(cvk, CGV_STRING)) == NULL)
	goto done;
    cv_name_set(cv, "k");
    cv_string_set(cv, "5");
    /* Use form 2c use spec of xc + name */
    if (clixon_xml_find_index(xc, NULL, NULL, "y3", cvk, &xvec, &xlen) < 0)
       goto done;
    if (xlen)
       val = xml_find_body(xvec[0], "val");
    else
       val = NULL;
    clicon_debug(1, "%s Method 3: val:%s", __FUNCTION__, val?val:"null");

    cprintf(cbret, "<rpc-reply><ok/></rpc-reply>");
    retval = 0;
  done:
    clicon_debug(1, "%s retval:%d", __FUNCTION__, retval);
    if (cvk)
	cvec_free(cvk);
    if (xret)
        xml_free(xret);
    if (xvec)
        free(xvec);
    return retval;
}

clixon_plugin_api *clixon_plugin_init(clicon_handle h);

static clixon_plugin_api api = {
    "order",            /* name */           /*--- Common fields.  ---*/
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
			      "urn:example:api",
			      "trigger"/* Xml tag when callback is made */
			      ) < 0)
	return NULL;
    return &api;
}

EOF

new "compile $cfile"
gcc -g -Wall -rdynamic -fPIC -shared $cfile -o $sofile

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

XML='<c xmlns="urn:example:api"><y3><k>2</k></y3><y3><k>3</k></y3><y3><k>5</k><val>zorro</val></y3><y3><k>7</k></y3></c>'

# Add a set of entries using restconf
new "PUT a set of entries"
expectpart "$(curl -si -X PUT -H 'Content-Type: application/yang-data+xml' http://localhost/restconf/data/example-api:c -d "$XML")" 0 "HTTP/1.1 201 Created"

new "Check entries"
expectpart "$(curl -si -X GET http://localhost/restconf/data/example-api:c -H 'Accept: application/yang-data+xml')" 0 'HTTP/1.1 200 OK' "$XML"

new "Send a trigger"
expectpart "$(curl -si -X POST http://localhost/restconf/operations/example-api:trigger -H 'Accept: application/yang-data+json')" 0 'HTTP/1.1 204 No Content'

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
