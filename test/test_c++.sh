#!/usr/bin/env bash
# Tests C++ compatibility with clixon
# The test compiles a c++ backend plugin, installs it and starts the backend, and then runs
# an RPC example.
# The RPC example is the "example" RPC in clixon-example.yang

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

cfile=$dir/c++.cpp

APPNAME=example
fyang=$dir/clixon-example.yang
cfg=$dir/conf.xml

test -d $dir/backend || mkdir $dir/backend

cat <<EOF > $cfg
<clixon-config xmlns="http://clicon.org/config">
  <CLICON_CONFIGFILE>$cfg</CLICON_CONFIGFILE>
  <CLICON_YANG_DIR>${YANG_INSTALLDIR}</CLICON_YANG_DIR>
  <CLICON_YANG_MAIN_FILE>$fyang</CLICON_YANG_MAIN_FILE>	
  <CLICON_BACKEND_DIR>$dir/backend</CLICON_BACKEND_DIR>
  <CLICON_CLISPEC_DIR>/usr/local/lib/$APPNAME/clispec</CLICON_CLISPEC_DIR>
  <CLICON_CLI_DIR>/usr/local/lib/$APPNAME/cli</CLICON_CLI_DIR>
  <CLICON_CLI_MODE>$APPNAME</CLICON_CLI_MODE>
  <CLICON_SOCK>/usr/local/var/$APPNAME/$APPNAME.sock</CLICON_SOCK>
  <CLICON_BACKEND_PIDFILE>/usr/local/var/$APPNAME/$APPNAME.pidfile</CLICON_BACKEND_PIDFILE>
  <CLICON_XMLDB_DIR>/usr/local/var/$APPNAME</CLICON_XMLDB_DIR>
</clixon-config>
EOF

cat <<EOF > $fyang
module clixon-example{
  yang-version 1.1;
  namespace "urn:example:clixon";
  prefix ex;
  rpc example {
	description "Some example input/output for testing RFC7950 7.14.
                     RPC simply echoes the input for debugging.";
	input {
	    leaf x {
		description
         	    "If a leaf in the input tree has a 'mandatory' statement with
                   the value 'true', the leaf MUST be present in an RPC invocation.";
		type string;
		mandatory true;
	    }
	    leaf y {
		description
                 "If a leaf in the input tree has a 'mandatory' statement with the
                  value 'true', the leaf MUST be present in an RPC invocation.";
		type string;
		default "42";
	    }
	}
	output {
	    leaf x {
		type string;
	    }
	    leaf y {
		type string;
	    }
	}
    }
}
EOF

cat<<EOF > $cfile
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <syslog.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/param.h>

#include <cligen/cligen.h>
#include <clixon/clixon.h>
#include <clixon/clixon_netconf.h>

/*! Plugin start
 * Called once everything has been initialized, right before
 * the main event loop is entered.
 */

clixon_plugin_api * clixon_plugin_init(clicon_handle h);

int plugin_start(clicon_handle h)
{
    return 0;
}

int plugin_exit(clicon_handle h)
{
    return 0;
}

class netconf_test
{
private:
    struct clixon_plugin_api api;

public:
    netconf_test(plginit2_t* init, plgstart_t* start, plgexit_t* exit, const char* str = "c++ netconf test") : api()
    {
        strcpy(api.ca_name, str);
        api.ca_init = clixon_plugin_init;
        api.ca_start = plugin_start;
        api.ca_exit = plugin_exit;
    }

    clixon_plugin_api* get_api(void)
    {
        return &api;
    }
};

static netconf_test api(clixon_plugin_init, plugin_start, plugin_exit);

/*! Local example netconf rpc callback
 */
int example_rpc(clicon_handle h,
		   cxobj        *xe,
		   cbuf         *cbret,
		   void         *arg,
		   void         *regarg)
{
    int    retval = -1;
    cxobj *x = NULL;
    char  *ns;

    /* get namespace from rpc name, return back in each output parameter */
    if ((ns = xml_find_type_value(xe, NULL, "xmlns", CX_ATTR)) == NULL)
    {
	      clicon_err(OE_XML, ENOENT, "No namespace given in rpc %s", xml_name(xe));
	      goto done;
    }
    cprintf(cbret, "<rpc-reply xmlns=\"%s\">", NETCONF_BASE_NAMESPACE);
    if (!xml_child_nr_type(xe, CX_ELMNT))
	      cprintf(cbret, "<ok/>");
    else{
        while ((x = xml_child_each(xe, x, CX_ELMNT)) != NULL) {
            if (xmlns_set(x, NULL, ns) < 0)
                goto done;
        }
        if (clixon_xml2cbuf(cbret, xe, 0, 0, -1, 1) < 0)
           goto done;
    }
    cprintf(cbret, "</rpc-reply>");
    retval = 0;
    done:
    return retval;
    return 0;
}

/*! Netconf plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 */
clixon_plugin_api* clixon_plugin_init(clicon_handle h)
{
    clicon_debug(1, "%s netconf", __FUNCTION__);
    /* Register local netconf rpc client (note not backend rpc client) */
    if (rpc_callback_register(h, example_rpc, NULL, "urn:example:clixon", "example") < 0)
	      return NULL;

    return api.get_api();
}
EOF

new "C++ compile"
# -I /usr/local_include for eg freebsd
expectpart "$($CXX -g -Wall -rdynamic -fPIC -shared -I/usr/local/include $cfile -o $dir/backend/c++.so)" 0 ""

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

new "Netconf runtime test"
expecteof_netconf "$clixon_netconf -qf $cfg" 0 "$DEFAULTHELLO" "<rpc $DEFAULTNS><example xmlns=\"urn:example:clixon\"><x>0</x></example></rpc>" "" "<rpc-reply $DEFAULTNS><x xmlns=\"urn:example:clixon\">0</x><y xmlns=\"urn:example:clixon\">42</y></rpc-reply>"

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

rm -rf $dir

new "endtest"
endtest
