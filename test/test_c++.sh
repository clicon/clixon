#!/usr/bin/env bash
# Tests cpp compatibility with clixon

cfile=$dir/c++.cpp

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
int
plugin_start(clicon_handle h)
{
    return 0;
}

int
plugin_exit(clicon_handle h)
{
    return 0;
}

/*! Local example netconf rpc callback
 */
int
netconf_client_rpc(clicon_handle h,
		   cxobj        *xe,
		   cbuf         *cbret,
		   void         *arg,
		   void         *regarg)
{
    int    retval = -1;
    cxobj *x = NULL;
    char  *ns;

    /* get namespace from rpc name, return back in each output parameter */
    if ((ns = xml_find_type_value(xe, NULL, "xmlns", CX_ATTR)) == NULL){
	clicon_err(OE_XML, ENOENT, "No namespace given in rpc %s", xml_name(xe));
	goto done;
    }
    cprintf(cbret, "<rpc-reply>");
    if (!xml_child_nr_type(xe, CX_ELMNT))
	cprintf(cbret, "<ok/>");
    else while ((x = xml_child_each(xe, x, CX_ELMNT)) != NULL) {
	    if (xmlns_set(x, NULL, ns) < 0)
		goto done;
	    if (clicon_xml2cbuf(cbret, x, 0, 0, -1) < 0)
		goto done;
	}
    cprintf(cbret, "</rpc-reply>");
    retval = 0;
 done:
    return retval;

    return 0;
}

clixon_plugin_api * clixon_plugin_init(clicon_handle h);

static struct clixon_plugin_api api;

void api_initialization(void)
{
    strcpy(api.ca_name, "c++ netconf test");     /* name */
    api.ca_init = clixon_plugin_init;            /* init */
    api.ca_start = plugin_start;                 /* start */
    api.ca_exit = plugin_exit;                   /* exit */
};

/*! Netconf plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{

	api_initialization();

    clicon_debug(1, "%s netconf", __FUNCTION__);
    /* Register local netconf rpc client (note not backend rpc client) */
    if (rpc_callback_register(h, netconf_client_rpc, NULL,
			      "urn:example:clixon", "client-rpc") < 0)
	return NULL;
    return &api;
}

EOF

g++ -g -Wall -rdynamic -fPIC -shared $cfile -o c++.o

rm -f c++.o
rm -rf $dir

