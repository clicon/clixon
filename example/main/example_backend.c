/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  Alternatively, the contents of this file may be used under the terms of
  the GNU General Public License Version 3 or later (the "GPL"),
  in which case the provisions of the GPL are applicable instead
  of those above. If you wish to allow use of your version of this file only
  under the terms of the GPL, and not to allow others to
  use your version of this file under the terms of Apache License version 2, indicate
  your decision by deleting the provisions above and replace them with the 
  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****

 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <assert.h>
#include <syslog.h>
#include <sys/time.h>

/* clicon */
#include <cligen/cligen.h>

/* Clicon library functions. */
#include <clixon/clixon.h>

/* These include signatures for plugin and transaction callbacks. */
#include <clixon/clixon_backend.h> 

/*! Variable to control if reset code is run.
 * The reset code inserts "extra XML" which assumes ietf-interfaces is
 * loaded, and this is not always the case.
 * Therefore, the backend must be started with -- -r to enable the reset function
 */
static int _reset = 0;

/*! Variable to control if state code is run
 * The state code adds extra non-config data
 * Therefore, the backend must be started with -- -s to enable the state function
 */
static int _state = 0;

/*! Variable to control upgrade callbacks.
 * If set, call test-case for upgrading ietf-interfaces, otherwise call 
 * auto-upgrade
 */
static int _upgrade = 0;

/* forward */
static int example_stream_timer_setup(clicon_handle h);

/*! This is called on validate (and commit). Check validity of candidate
 */
int
transaction_validate(clicon_handle    h, 
		     transaction_data td)
{
    //    transaction_print(stderr, td);
    return 0;
}

/*! This is called on commit. Identify modifications and adjust machine state
 */
int
transaction_commit(clicon_handle    h, 
		   transaction_data td)
{
    cxobj  *target = transaction_target(td); /* wanted XML tree */
    cxobj **vec = NULL;
    int     i;
    size_t  len;

    clicon_debug(1, "%s", __FUNCTION__);
    /* Get all added i/fs */
    if (xpath_vec_flag(target, "//interface", XML_FLAG_ADD, &vec, &len) < 0)
	return -1;
    if (debug)
	for (i=0; i<len; i++)             /* Loop over added i/fs */
	    xml_print(stdout, vec[i]); /* Print the added interface */
  // done:
    if (vec)
	free(vec);
    return 0;
}

/*! Routing example notification timer handler. Here is where the periodic action is 
 */
static int
example_stream_timer(int   fd, 
		     void *arg)
{
    int                    retval = -1;
    clicon_handle          h = (clicon_handle)arg;

    /* XXX Change to actual netconf notifications and namespace */
    if (stream_notify(h, "EXAMPLE", "<event xmlns=\"urn:example:clixon\"><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>") < 0)
	goto done;
    if (example_stream_timer_setup(h) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

/*! Set up example stream notification timer 
 */
static int
example_stream_timer_setup(clicon_handle h)
{
    struct timeval t, t1;

    gettimeofday(&t, NULL);
    t1.tv_sec = 5; t1.tv_usec = 0;
    timeradd(&t, &t1, &t);
    return event_reg_timeout(t, example_stream_timer, h, "example stream timer");
}

/*! Smallest possible RPC declaration for test 
 * Yang/XML:
 * If the RPC operation invocation succeeded and no output parameters
 * are returned, the <rpc-reply> contains a single <ok/> element defined
 * in [RFC6241].
 */
static int 
empty_rpc(clicon_handle h,            /* Clicon handle */
	  cxobj        *xe,           /* Request: <rpc><xn></rpc> */
	  cbuf         *cbret,        /* Reply eg <rpc-reply>... */
	  void         *arg,          /* client_entry */
	  void         *regarg)       /* Argument given at register */
{
    cprintf(cbret, "<rpc-reply><ok/></rpc-reply>");
    return 0;
}

/*! More elaborate example RPC for testing
 * The RPC returns the incoming parameters
 */
static int 
example_rpc(clicon_handle h,            /* Clicon handle */
	    cxobj        *xe,           /* Request: <rpc><xn></rpc> */
	    cbuf         *cbret,        /* Reply eg <rpc-reply>... */
	    void         *arg,          /* client_entry */
	    void         *regarg)       /* Argument given at register */
{
    int    retval = -1;
    cxobj *x = NULL;
    char  *namespace;

    /* get namespace from rpc name, return back in each output parameter */
    if ((namespace = xml_find_type_value(xe, NULL, "xmlns", CX_ATTR)) == NULL){
	clicon_err(OE_XML, ENOENT, "No namespace given in rpc %s", xml_name(xe));
	goto done;
    }
    cprintf(cbret, "<rpc-reply>");
    if (!xml_child_nr_type(xe, CX_ELMNT))
	cprintf(cbret, "<ok/>");
    else while ((x = xml_child_each(xe, x, CX_ELMNT)) != NULL) {
	    if (xmlns_set(x, NULL, namespace) < 0)
		goto done;
	    if (clicon_xml2cbuf(cbret, x, 0, 0) < 0)
		goto done;
	}
    cprintf(cbret, "</rpc-reply>");
    retval = 0;
 done:
    return retval;
}

/*! This will be called as a hook right after the original system copy-config
 */
static int 
example_copy_extra(clicon_handle h,            /* Clicon handle */
		   cxobj        *xe,           /* Request: <rpc><xn></rpc> */
		   cbuf         *cbret,        /* Reply eg <rpc-reply>... */
		   void         *arg,          /* client_entry */
		   void         *regarg)       /* Argument given at register */
{
    int    retval = -1;

    fprintf(stderr, "%s\n", __FUNCTION__);
    retval = 0;
    // done:
    return retval;
}

/*! Called to get state data from plugin
 * @param[in]    h      Clicon handle
 * @param[in]    xpath  String with XPATH syntax. or NULL for all
 * @param[in]    xtop   XML tree, <config/> on entry. 
 * @retval       0      OK
 * @retval      -1      Error
 * @see xmldb_get
 * @note this example code returns requires this yang snippet:
       container state {
         config false;
         description "state data for example application";
         leaf-list op {
            type string;
         }
       }
 * This yang snippet is present in clixon-example.yang for exampl.
 */
int 
example_statedata(clicon_handle h, 
		 char         *xpath,
		 cxobj        *xstate)
{
    int     retval = -1;
    cxobj **xvec = NULL;

    if (!_state)
	goto ok;
    /* Example of (static) statedata, real code would poll state 
     * Note this state needs to be accomanied by yang snippet
     * above
     */
    if (xml_parse_string("<state xmlns=\"urn:example:clixon\">"
			 "<op>42</op>"
			 "<op>41</op>"
			 "<op>43</op>" /* should not be ordered */
			 "</state>", NULL, &xstate) < 0)
	goto done;
 ok:
    retval = 0;
 done:
    if (xvec)
	free(xvec);
    return retval;
}

/*! Testcase upgrade function moving interfaces-state to interfaces
 * @param[in]  h       Clicon handle 
 * @param[in]  xn      XML tree to be updated
 * @param[in]  ns      Namespace of module (for info)
 * @param[in]  from    From revision on the form YYYYMMDD
 * @param[in]  to      To revision on the form YYYYMMDD (0 not in system)
 * @param[in]  arg     User argument given at rpc_callback_register() 
 * @param[out] cbret   Return xml tree, eg <rpc-reply>..., <rpc-error.. 
 * @retval     1       OK
 * @retval     0       Invalid
 * @retval    -1       Error
 * @see clicon_upgrade_cb
 * @see test_upgrade_interfaces.sh
 * @see upgrade_2016
 * This example shows a two-step upgrade where the 2014 function does:
 * - Move /if:interfaces-state/if:interface/if:admin-status to 
 *        /if:interfaces/if:interface/
 * - Move /if:interfaces-state/if:interface/if:statistics to
 *        /if:interfaces/if:interface/
 * - Rename /interfaces/interface/description to descr 
 */
static int
upgrade_2016(clicon_handle h,       
	     cxobj        *xt,      
	     char         *ns,
	     uint32_t      from,
	     uint32_t      to,
	     void         *arg,     
	     cbuf         *cbret)
{
    int        retval = -1;
    yang_stmt *yspec;
    yang_stmt *ym;
    cxobj    **vec = NULL;
    cxobj     *xc;
    cxobj     *xi;  /* xml /interfaces-states/interface node */
    cxobj     *x;
    cxobj     *xif; /* xml /interfaces/interface node */
    size_t     vlen;
    int        i;
    char      *name;

    /* Get Yang module for this namespace. Note it may not exist (if obsolete) */
    yspec = clicon_dbspec_yang(h);	
    if ((ym = yang_find_module_by_namespace(yspec, ns)) == NULL)
	goto ok; /* shouldnt happen */
    clicon_debug(1, "%s module %s", __FUNCTION__, ym?ym->ys_argument:"none");
    /* Get all XML nodes with that namespace */
    if (xml_namespace_vec(h, xt, ns, &vec, &vlen) < 0)
	goto done;
    for (i=0; i<vlen; i++){
	xc = vec[i];
	/* Iterate through interfaces-state */
	if (strcmp(xml_name(xc),"interfaces-state") == 0){
	    /* Note you cannot delete or move xml objects directly under xc
	     * in the loop (eg xi objects) but you CAN move children of xi
	     */
	    xi = NULL;
	    while ((xi = xml_child_each(xc, xi, CX_ELMNT)) != NULL) {
		if (strcmp(xml_name(xi), "interface"))
		    continue;
		if ((name = xml_find_body(xi, "name")) == NULL)
		    continue; /* shouldnt happen */
		/* Get corresponding /interfaces/interface entry */
		xif = xpath_first(xt, "/interfaces/interface[name=\"%s\"]", name);
		/* - Move /if:interfaces-state/if:interface/if:admin-status to 
		 *        /if:interfaces/if:interface/ */
		if ((x = xml_find(xi, "admin-status")) != NULL && xif){
		    if (xml_addsub(xif, x) < 0)
			goto done;
		}
		/* - Move /if:interfaces-state/if:interface/if:statistics to
		 *        /if:interfaces/if:interface/*/
		if ((x = xml_find(xi, "statistics")) != NULL){
		    if (xml_addsub(xif, x) < 0)
			goto done;
		}
	    }
	}
	else if (strcmp(xml_name(xc),"interfaces") == 0){
	    /* Iterate through interfaces */
	    xi = NULL;
	    while ((xi = xml_child_each(xc, xi, CX_ELMNT)) != NULL) {
		if (strcmp(xml_name(xi), "interface"))
		    continue;
		/* Rename /interfaces/interface/description to descr */
		if ((x = xml_find(xi, "description")) != NULL)
		    if (xml_name_set(x, "descr") < 0)
			goto done;
	    }
	}
    }
 ok:
    retval = 1;
 done:
    if (vec)
	free(vec);
    return retval;
}

/*! Testcase upgrade function removing interfaces-state
 * @param[in]  h       Clicon handle 
 * @param[in]  xn      XML tree to be updated
 * @param[in]  ns      Namespace of module (for info)
 * @param[in]  from    From revision on the form YYYYMMDD
 * @param[in]  to      To revision on the form YYYYMMDD (0 not in system)
 * @param[in]  arg     User argument given at rpc_callback_register() 
 * @param[out] cbret   Return xml tree, eg <rpc-reply>..., <rpc-error.. 
 * @retval     1       OK
 * @retval     0       Invalid
 * @retval    -1       Error
 * @see clicon_upgrade_cb
 * @see test_upgrade_interfaces.sh
 * @see upgrade_2016
 * The 2016 function does:
 * - Delete /if:interfaces-state
 * - Wrap /interfaces/interface/descr to /interfaces/interface/docs/descr
 * - Change type /interfaces/interface/statistics/in-octets to decimal64 with
 *   fraction-digits 3 and divide all values with 1000
 */
static int
upgrade_2018(clicon_handle h,       
	     cxobj        *xt,      
	     char         *ns,
	     uint32_t      from,
	     uint32_t      to,
	     void         *arg,     
	     cbuf         *cbret)
{
    int        retval = -1;
    yang_stmt *yspec;
    yang_stmt *ym;
    cxobj    **vec = NULL;
    cxobj     *xc;
    cxobj     *xi;
    cxobj     *x;
    cxobj     *xb;
    size_t     vlen;
    int        i;

    /* Get Yang module for this namespace. Note it may not exist (if obsolete) */
    yspec = clicon_dbspec_yang(h);	
    if ((ym = yang_find_module_by_namespace(yspec, ns)) == NULL)
	goto ok; /* shouldnt happen */
    clicon_debug(1, "%s module %s", __FUNCTION__, ym?ym->ys_argument:"none");
    /* Get all XML nodes with that namespace */
    if (xml_namespace_vec(h, xt, ns, &vec, &vlen) < 0)
	goto done;
    for (i=0; i<vlen; i++){
	xc = vec[i];
	/* Delete /if:interfaces-state */
	if (strcmp(xml_name(xc), "interfaces-state") == 0)
	    xml_purge(xc);
	/* Iterate through interfaces */
	else if (strcmp(xml_name(xc),"interfaces") == 0){
	    /* Iterate through interfaces */
	    xi = NULL;
	    while ((xi = xml_child_each(xc, xi, CX_ELMNT)) != NULL) {
		if (strcmp(xml_name(xi), "interface"))
		    continue;
		/* Wrap /interfaces/interface/descr to /interfaces/interface/docs/descr */
		if ((x = xml_find(xi, "descr")) != NULL)
		    if (xml_wrap(x, "docs") < 0)
			goto done;
		/* Change type /interfaces/interface/statistics/in-octets to 
		 * decimal64 with fraction-digits 3 and divide values with 1000 
		 */
		if ((x = xpath_first(xi, "statistics/in-octets")) != NULL){
		    if ((xb = xml_body_get(x)) != NULL){
			uint64_t u64;
			cbuf *cb = cbuf_new();
			parse_uint64(xml_value(xb), &u64, NULL);
			cprintf(cb, "%" PRIu64 ".%03d", u64/1000, (int)(u64%1000));
			xml_value_set(xb, cbuf_get(cb));
			cbuf_free(cb);
		    }
		}
	    }
	}
    }
 ok:
    retval = 1;
 done:
    if (vec)
	free(vec);
    return retval;
}

/*! Plugin state reset. Add xml or set state in backend machine.
 * Called in each backend plugin. plugin_reset is called after all plugins
 * have been initialized. This give the application a chance to reset
 * system state back to a base state. 
 * This is generally done when a system boots up to
 * make sure the initial system state is well defined. This can be creating
 * default configuration files for various daemons, set interface flags etc.
 * @param[in] h   Clicon handle
 * @param[in] db  Name of database. Not may be other than "running"
 * In this example, a loopback interface is added
 * @note This assumes example yang with interfaces/interface
 */
int
example_reset(clicon_handle h,
	      const char   *db)
{
    int    retval = -1;
    cxobj *xt = NULL;
    int    ret;
    cbuf  *cbret = NULL;

    if (!_reset)
	goto ok; /* Note not enabled by default */
    if (xml_parse_string("<config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\"><interface>"
			 "<name>lo</name><type>ex:loopback</type>"
			 "</interface></interfaces></config>", NULL, &xt) < 0)
	goto done;
    /* Replace parent w first child */
    if (xml_rootchild(xt, 0, &xt) < 0)
	goto done;
    if ((cbret = cbuf_new()) == NULL){
	clicon_err(OE_UNIX, errno, "cbuf_new");
	goto done;
    }
    /* Merge user reset state */
    if ((ret = xmldb_put(h, (char*)db, OP_MERGE, xt, clicon_username_get(h), cbret)) < 0)
	goto done;
    if (ret == 0){
	clicon_err(OE_XML, 0, "Error when writing to XML database: %s",
		   cbuf_get(cbret));
	goto done;
    }
 ok:
    retval = 0;
 done:
    if (cbret)
	cbuf_free(cbret);
    if (xt != NULL)
	xml_free(xt);
    return retval;
}

/*! Plugin start.
 * @param[in]  h     Clicon handle
 *
 * plugin_start is called once everything has been initialized, right before 
 * the main event loop is entered. 
 */
int
example_start(clicon_handle h)
{
    return 0;
}

int 
example_exit(clicon_handle h)
{
    return 0;
}

clixon_plugin_api *clixon_plugin_init(clicon_handle h);

static clixon_plugin_api api = {
    "example",                              /* name */    
    clixon_plugin_init,                     /* init - must be called clixon_plugin_init */
    example_start,                          /* start */
    example_exit,                           /* exit */
    .ca_reset=example_reset,                /* reset */
    .ca_statedata=example_statedata,        /* statedata */
    .ca_trans_begin=NULL,                   /* trans begin */
    .ca_trans_validate=transaction_validate,/* trans validate */
    .ca_trans_complete=NULL,                /* trans complete */
    .ca_trans_commit=transaction_commit,    /* trans commit */
    .ca_trans_end=NULL,                     /* trans end */
    .ca_trans_abort=NULL                    /* trans abort */
};

/*! Backend plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 * In this example, you can pass -r, -s, -u to control the behaviour, mainly 
 * for use in the test suites.
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    struct timeval retention = {0,0};
    int            argc; /* command-line options (after --) */
    char         **argv;
    char           c;

    clicon_debug(1, "%s backend", __FUNCTION__);

    /* Get user command-line options (after --) */
    if (clicon_argv_get(h, &argc, &argv) < 0)
	goto done;
    opterr = 0;
    optind = 1;
    while ((c = getopt(argc, argv, "rsu")) != -1)
	switch (c) {
	case 'r':
	    _reset = 1;
	    break;
	case 's':
	    _state = 1;
	    break;
	case 'u':
	    _upgrade = 1;
	    break;
	}

    /* Example stream initialization:
     * 1) Register EXAMPLE stream 
     * 2) setup timer for notifications, so something happens on stream
     * 3) setup stream callbacks for notification to push channel
     */
    if (clicon_option_exists(h, "CLICON_STREAM_RETENTION"))
	retention.tv_sec = clicon_option_int(h, "CLICON_STREAM_RETENTION");
    if (stream_add(h, "EXAMPLE", "Example event stream", 1, &retention) < 0)
	goto done;
    /* Enable nchan pub/sub streams
     * assumes: CLIXON_PUBLISH_STREAMS, eg configure --enable-publish
     */
    if (clicon_option_exists(h, "CLICON_STREAM_PUB") &&
	stream_publish(h, "EXAMPLE") < 0)
	goto done;
    if (example_stream_timer_setup(h) < 0)
	goto done;

    /* Register callback for routing rpc calls 
     */
    /* From example.yang (clicon) */
    if (rpc_callback_register(h, empty_rpc, 
			      NULL, 
			      "urn:example:clixon",
			      "empty"/* Xml tag when callback is made */
			      ) < 0)
	goto done;
    /* Same as example but with optional input/output */
    if (rpc_callback_register(h, example_rpc, 
			      NULL, 
			      "urn:example:clixon",
			      "optional"/* Xml tag when callback is made */
			      ) < 0)
	goto done;
        /* Same as example but with optional input/output */
    if (rpc_callback_register(h, example_rpc, 
			      NULL, 
			      "urn:example:clixon",
			      "example"/* Xml tag when callback is made */
			      ) < 0)
	goto done;
    /* Called after the regular system copy_config callback */
    if (rpc_callback_register(h, example_copy_extra, 
			      NULL, 
			      "urn:ietf:params:xml:ns:netconf:base:1.0",
			      "copy-config"
			      ) < 0)
	goto done;
    /* Upgrade callback: if you start the backend with -- -u you will get the
     * test interface example. Otherwise the auto-upgrade feature is enabled.
     */
    if (_upgrade){
	if (upgrade_callback_register(h, upgrade_2016, "urn:example:interfaces", 20140508, 20160101, NULL) < 0)
	    goto done;
	if (upgrade_callback_register(h, upgrade_2018, "urn:example:interfaces", 20160101, 20180220, NULL) < 0)
	    goto done;
    }
    else
	if (upgrade_callback_register(h, xml_changelog_upgrade, NULL, 0, 0, NULL) < 0)
	    goto done;

    /* Return plugin API */
    return &api;
 done:
    return NULL;
}
