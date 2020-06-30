/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

  * The example have the following optional arguments that you can pass as 
  * argc/argv after -- in clixon_backend:
  *  -r  enable the reset function 
  *  -s  enable the state function
  *  -S <file>  read state data from file, otherwise construct it programmatically (requires -s)
  *  -i  read state file on init not by request for optimization (requires -sS <file>)
  *  -u  enable upgrade function - auto-upgrade testing
  *  -U  general-purpose upgrade
  *  -t  enable transaction logging (cal syslog for every transaction)
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <syslog.h>
#include <fcntl.h>
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
 * Start backend with -- -r
 */
static int _reset = 0;

/*! Variable to control if state code is run
 * The state code adds extra non-config data
 * Start backend with -- -s
 */
static int _state = 0;

/*! File where state XML is read from, if _state is true -- -sS <file>
 * Primarily for testing
 * Start backend with -- -sS <file>
 */
static char *_state_file = NULL;

/*! Read state file init on startup instead of on request
 * Primarily for testing
 * Start backend with -- -siS <file>
 */
static int _state_file_init = 0;
static cxobj *_state_xstate = NULL;

/*! Variable to control module-specific upgrade callbacks.
 * If set, call test-case for upgrading ietf-interfaces, otherwise call 
 * auto-upgrade
 * Start backend with -- -u
 */
static int _module_upgrade = 0;

/*! Variable to control general-purpose upgrade callbacks.
 * Start backend with -- -U
 */
static int _general_upgrade = 0;

/*! Variable to control transaction logging (for debug)
 * If set, call syslog for every transaction callback 
 * Start backend with -- -t
 */
static int _transaction_log = 0;

/* forward */
static int example_stream_timer_setup(clicon_handle h);

int
main_begin(clicon_handle    h, 
	   transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}
/*! This is called on validate (and commit). Check validity of candidate
 */
int
main_validate(clicon_handle    h, 
	      transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

int
main_complete(clicon_handle    h, 
	      transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

/*! This is called on commit. Identify modifications and adjust machine state
 */
int
main_commit(clicon_handle    h, 
	    transaction_data td)
{
    cxobj  *target = transaction_target(td); /* wanted XML tree */
    cxobj **vec = NULL;
    int     i;
    int     len;
    cvec   *nsc = NULL;

    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);

    /* Create namespace context for xpath */
    if ((nsc = xml_nsctx_init(NULL, "urn:ietf:params:xml:ns:yang:ietf-interfaces")) == NULL)
	goto done;

    /* Get all added i/fs */
    if (xpath_vec_flag(target, nsc, "//interface", XML_FLAG_ADD, &vec, &len) < 0)
	return -1;
    if (clicon_debug_get())
	for (i=0; i<len; i++)             /* Loop over added i/fs */
	    xml_print(stdout, vec[i]); /* Print the added interface */
  done:
    if (nsc)
	xml_nsctx_free(nsc);
    if (vec)
	free(vec);
    return 0;
}

int
main_commit_done(clicon_handle    h, 
		 transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

int
main_revert(clicon_handle    h, 
	    transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

int
main_end(clicon_handle    h, 
	 transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
    return 0;
}

int
main_abort(clicon_handle    h, 
	   transaction_data td)
{
    if (_transaction_log)
	transaction_log(h, td, LOG_NOTICE, __FUNCTION__);
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
    return clixon_event_reg_timeout(t, example_stream_timer, h, "example stream timer");
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
	    if (clicon_xml2cbuf(cbret, x, 0, 0, -1) < 0)
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

    //    fprintf(stderr, "%s\n", __FUNCTION__);
    retval = 0;
    // done:
    return retval;
}

/*! Called to get state data from plugin
 * @param[in]    h      Clicon handle
 * @param[in]    nsc    External XML namespace context, or NULL
 * @param[in]    xpath  String with XPATH syntax. or NULL for all
 * @param[in]    xstate XML tree, <config/> on entry. 
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
 * This yang snippet is present in clixon-example.yang for example.
 */
int 
example_statedata(clicon_handle h, 
		  cvec         *nsc,
		  char         *xpath,
		  cxobj        *xstate)
{
    int     retval = -1;
    cxobj **xvec = NULL;
    size_t  xlen = 0;
    cbuf   *cb = cbuf_new();
    int     i;
    cxobj  *xt = NULL;
    char   *name;
    cvec   *nsc1 = NULL;
    cvec   *nsc2 = NULL;
    yang_stmt *yspec = NULL;
    int     fd;

    if (!_state)
	goto ok;
    yspec = clicon_dbspec_yang(h);
    
    /* If -S is set, then read state data from file, otherwise construct it programmatically */
    if (_state_file){
	if (_state_file_init){
#if 0 /* This is just for a zero-copy version (only works once) */
	    {
		cxobj *xx = NULL;
		while (xml_child_nr(_state_xstate)){
		    xx = xml_child_i(_state_xstate,0);
		    if (xml_addsub(xstate, xx) < 0)
			goto done;
		}
	    }
#else
	    if (xml_copy(_state_xstate, xstate) < 0)
		goto done;
#endif
	}
	else{
	    cxobj *x1;
	    if ((fd = open(_state_file, O_RDONLY)) < 0){
		clicon_err(OE_UNIX, errno, "open(%s)", _state_file);
		goto done;
	    }
	    if (clixon_xml_parse_file(fd, YB_MODULE, yspec, NULL, &xt, NULL) < 0)
		goto done;
	    close(fd);
	    if (xpath_vec(xt, nsc, "%s", &xvec, &xlen, xpath) < 0) 
		goto done;
	    for (i=0; i<xlen; i++){
		x1 = xvec[i];
		xml_flag_set(x1, XML_FLAG_MARK);
	    }
	    /* Remove everything that is not marked */
	    if (xml_tree_prune_flagged_sub(xt, XML_FLAG_MARK, 1, NULL) < 0)
		goto done;
	    for (i=0; i<xlen; i++){
		x1 = xvec[i];
		xml_flag_reset(x1, XML_FLAG_MARK);
	    }
	    if (xml_copy(xt, xstate) < 0)
		goto done;

	    if (xvec){
		free(xvec);
		xvec = 0;
		xlen = 0;
	    }
	}
    }
    else {
	/* Example of statedata, in this case merging state data with 
	 * state information. In this case adding dummy interface operation state
	 * to configured interfaces.
	 * Get config according to xpath */
	if ((nsc1 = xml_nsctx_init(NULL, "urn:ietf:params:xml:ns:yang:ietf-interfaces")) == NULL)
	    goto done;
	if (xmldb_get0(h, "running", nsc1, "/interfaces/interface/name", 1, &xt, NULL) < 0)
	    goto done;
	if (xpath_vec(xt, nsc1, "/interfaces/interface/name", &xvec, &xlen) < 0)
	    goto done;
	if (xlen){
	    cprintf(cb, "<interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">");
	    for (i=0; i<xlen; i++){
		name = xml_body(xvec[i]);
		cprintf(cb, "<interface xmlns:ex=\"urn:example:clixon\"><name>%s</name><type>ex:eth</type><oper-status>up</oper-status>", name);
		cprintf(cb, "<ex:my-status><ex:int>42</ex:int><ex:str>foo</ex:str></ex:my-status>");
		cprintf(cb, "</interface>");
	    }
	    cprintf(cb, "</interfaces>");
	    if (clixon_xml_parse_string(cbuf_get(cb), YB_NONE, NULL, &xstate, NULL) < 0)
		goto done;
	}
	/* State in test_yang.sh , test_restconf.sh and test_order.sh */
	if (yang_find_module_by_namespace(yspec, "urn:example:clixon") != NULL){
	    if (clixon_xml_parse_string("<state xmlns=\"urn:example:clixon\">"
					"<op>42</op>"
					"<op>41</op>"
					"<op>43</op>" /* should not be ordered */
					"</state>",
					YB_NONE,
					NULL, &xstate, NULL) < 0)
		goto done; /* For the case when urn:example:clixon is not loaded */
	}
	/* Event state from RFC8040 Appendix B.3.1 
	 * Note: (1) order is by-system so is different, 
	 *       (2) event-count is XOR on name, so is not 42 and 4
	 */
	if (yang_find_module_by_namespace(yspec, "urn:example:events") != NULL){
	    cbuf_reset(cb);
	    cprintf(cb, "<events xmlns=\"urn:example:events\">");
	    cprintf(cb, "<event><name>interface-down</name><event-count>90</event-count></event>");
	    cprintf(cb, "<event><name>interface-up</name><event-count>77</event-count></event>");
	    cprintf(cb, "</events>");
	    if (clixon_xml_parse_string(cbuf_get(cb), YB_NONE, NULL, &xstate, NULL) < 0)
		goto done;
	}
    }
 ok:
    retval = 0;
 done:
    if (nsc1)
	xml_nsctx_free(nsc1);
    if (nsc2)
	xml_nsctx_free(nsc2);
    if (xt)
	xml_free(xt);
    if (cb)
	cbuf_free(cb);
    if (xvec)
	free(xvec);
    return retval;
}

/*! Callback for yang extensions example:e4
 * 
 * @param[in] h    Clixon handle
 * @param[in] yext Yang node of extension 
 * @param[in] ys   Yang node of (unknown) statement belonging to extension
 * @retval     0   OK, all callbacks executed OK
 * @retval    -1   Error in one callback
 */
int
example_extension(clicon_handle h,     
		  yang_stmt    *yext,
		  yang_stmt    *ys)
{
    int        retval = -1;
    char      *extname;
    char      *modname;
    yang_stmt *ymod;
    yang_stmt *yc;
    yang_stmt *yn = NULL;
    
    ymod = ys_module(yext);
    modname = yang_argument_get(ymod);
    extname = yang_argument_get(yext);
    if (strcmp(modname, "example") != 0 || strcmp(extname, "e4") != 0)
	goto ok;
    clicon_debug(1, "%s Enabled extension:%s:%s", __FUNCTION__, modname, extname);
    if ((yc = yang_find(ys, 0, NULL)) == NULL)
	goto ok;
    if ((yn = ys_dup(yc)) == NULL)
	goto done;
    if (yn_insert(yang_parent_get(ys), yn) < 0)
	goto done;
 ok:
    retval = 0;
 done:
    return retval;
}

/* Here follows code for general-purpose datastore upgrade
 * Nodes affected are identified by paths.
 * In this example nodes' namespaces are changed, or they are removed altogether
 * @note Order is significant, the rules are traversed in the order stated here, which means that if
 *       namespaces changed, or objects are removed in one rule, you have to take that into account
 *       in the next rule.
 */
/* Remove these paths */
static const char *remove_map[] = {
    "/a:remove_me",
    /* add more paths to be deleted here */
    NULL
};

/* Rename the namespaces of these paths. 
 * That is, paths (on the left) should get namespaces (to the right) 
 */
static const map_str2str namespace_map[] = {
    {"/a:x/a:y/a:z/descendant-or-self::node()", "urn:example:b"},
    /* add more paths to be renamed here */
    {NULL,                          NULL}
};

/*! General-purpose datastore upgrade callback called once on startup
 *
 * Gets called on startup after initial XML parsing, but before module-specific upgrades
 * and before validation. 
 * @param[in] h    Clicon handle
 * @param[in] db   Name of datastore, eg "running", "startup" or "tmp"
 * @param[in] xt   XML tree. Upgrade this "in place"
 * @param[in] msd  Info on datastore module-state, if any
 * @retval   -1    Error
 * @retval    0    OK
 */
int
example_upgrade(clicon_handle    h,
		char            *db,
		cxobj           *xt,
		modstate_diff_t *msd)
{
    int                       retval = -1;
    cvec                     *nsc = NULL;    /* Canonical namespace */
    yang_stmt                *yspec;    
    const struct map_str2str *ms;            /* map iterator */
    cxobj                   **xvec = NULL;   /* vector of result nodes */
    size_t                    xlen; 
    int                       i;
    const char              **pp;

    if (_general_upgrade == 0)
	goto ok;
    if (strcmp(db, "startup") != 0) /* skip other than startup datastore */
	goto ok;
    if (msd && msd->md_status) /* skip if there is proper module-state in datastore */
	goto ok;
    yspec = clicon_dbspec_yang(h);     /* Get all yangs */
    /* Get canonical namespaces for using "normalized" prefixes */
    if (xml_nsctx_yangspec(yspec, &nsc) < 0)
	goto done;
    /* 1. Remove paths */
    for (pp = remove_map; *pp; ++pp){
	/* Find all nodes matching n */
	if (xpath_vec(xt, nsc, "%s", &xvec, &xlen, *pp) < 0) 
	    goto done;
	/* Remove them */
	/* Loop through all nodes matching mypath and change theoir namespace */
	for (i=0; i<xlen; i++){
	    if (xml_purge(xvec[i]) < 0)
		goto done;
	}
	if (xvec){
	    free(xvec);
	    xvec = NULL;
	}
    }
    /* 2. Rename namespaces of the paths declared in the namespace map
     */
    for (ms = &namespace_map[0]; ms->ms_s0; ms++){
	char *mypath;
	char *mynamespace;
	char *myprefix = NULL;

	mypath = ms->ms_s0;
	mynamespace = ms->ms_s1;
	if (xml_nsctx_get_prefix(nsc, mynamespace, &myprefix) == 0){
	    clicon_err(OE_XML, ENOENT, "Namespace %s not found in canonical namespace map",
		       mynamespace);
	    goto done;
	}
	/* Find all nodes matching mypath */
	if (xpath_vec(xt, nsc, "%s", &xvec, &xlen, mypath) < 0) 
	    goto done;
	/* Loop through all nodes matching mypath and change theoir namespace */
	for (i=0; i<xlen; i++){
	    /* Change namespace of this node (using myprefix) */ 
	    if (xml_namespace_change(xvec[i], mynamespace, myprefix) < 0)
		goto done;
	}
	if (xvec){
	    free(xvec);
	    xvec = NULL;
	}
    }
 ok:
    retval = 0;
 done:
    if (xvec)
	free(xvec);
    if (nsc)
	cvec_free(nsc);
    return retval;
}

/*! Testcase module-specific upgrade function moving interfaces-state to interfaces
 * @param[in]  h       Clicon handle 
 * @param[in]  xn      XML tree to be updated
 * @param[in]  ns      Namespace of module (for info)
 * @param[in]  op      One of XML_FLAG_ADD, _DEL, _CHANGE
 * @param[in]  from    From revision on the form YYYYMMDD
 * @param[in]  to      To revision on the form YYYYMMDD (0 not in system)
 * @param[in]  arg     User argument given at rpc_callback_register() 
 * @param[out] cbret   Return xml tree, eg <rpc-reply>..., <rpc-error..  if retval = 0
 * @retval     1       OK
 * @retval     0       Invalid
 * @retval    -1       Error
 * @see clicon_upgrade_cb
 * @see test_upgrade_interfaces.sh
 * @see upgrade_2014_to_2016
 * This example shows a two-step upgrade where the 2014 function does:
 * - Move /if:interfaces-state/if:interface/if:admin-status to 
 *        /if:interfaces/if:interface/
 * - Move /if:interfaces-state/if:interface/if:statistics to
 *        /if:interfaces/if:interface/
 * - Rename /interfaces/interface/description to descr 
 */
static int
upgrade_2014_to_2016(clicon_handle h,       
		     cxobj        *xt,      
		     char         *ns,
		     uint16_t      op,
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

    clicon_debug(1, "%s from:%d to:%d", __FUNCTION__, from, to);
    /* Get Yang module for this namespace. Note it may not exist (if obsolete) */
    yspec = clicon_dbspec_yang(h);	
    if ((ym = yang_find_module_by_namespace(yspec, ns)) == NULL)
	goto ok; /* shouldnt happen */
    clicon_debug(1, "%s module %s", __FUNCTION__, ym?yang_argument_get(ym):"none");
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
		xif = xpath_first(xt, NULL, "/interfaces/interface[name=\"%s\"]", name);
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
 * @param[in]  op      One of XML_FLAG_ADD, _DEL, _CHANGE
 * @param[in]  from    From revision on the form YYYYMMDD
 * @param[in]  to      To revision on the form YYYYMMDD (0 not in system)
 * @param[in]  arg     User argument given at rpc_callback_register() 
 * @param[out] cbret   Return xml tree, eg <rpc-reply>..., <rpc-error..  if retval = 0
 * @retval     1       OK
 * @retval     0       Invalid
 * @retval    -1       Error
 * @see clicon_upgrade_cb
 * @see test_upgrade_interfaces.sh
 * @see upgrade_2016_to_2018
 * The 2016 function does:
 * - Delete /if:interfaces-state
 * - Wrap /interfaces/interface/descr to /interfaces/interface/docs/descr
 * - Change type /interfaces/interface/statistics/in-octets to decimal64 with
 *   fraction-digits 3 and divide all values with 1000
 */
static int
upgrade_2016_to_2018(clicon_handle h,       
		     cxobj        *xt,      
		     char         *ns,
		     uint16_t      op,
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

    clicon_debug(1, "%s from:%d to:%d", __FUNCTION__, from, to);
    /* Get Yang module for this namespace. Note it may not exist (if obsolete) */
    yspec = clicon_dbspec_yang(h);	
    if ((ym = yang_find_module_by_namespace(yspec, ns)) == NULL)
	goto ok; /* shouldnt happen */
    clicon_debug(1, "%s module %s", __FUNCTION__, ym?yang_argument_get(ym):"none");
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
		if ((x = xpath_first(xi, NULL, "statistics/in-octets")) != NULL){
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

/*! Testcase module-specific upgrade function moving interfaces-state to interfaces
 * @param[in]  h       Clicon handle 
 * @param[in]  xn      XML tree to be updated
 * @param[in]  ns      Namespace of module (for info)
 * @param[in]  op      One of XML_FLAG_ADD, _DEL, _CHANGE
 * @param[in]  from    From revision on the form YYYYMMDD
 * @param[in]  to      To revision on the form YYYYMMDD (0 not in system)
 * @param[in]  arg     User argument given at rpc_callback_register() 
 * @param[out] cbret   Return xml tree, eg <rpc-reply>..., <rpc-error..  if retval = 0
 * @retval     1       OK
 * @retval     0       Invalid
 * @retval    -1       Error
 * @see clicon_upgrade_cb
 * @see test_upgrade_interfaces.sh
 * @see upgrade_2014_to_2016
 * This example shows a two-step upgrade where the 2014 function does:
 * - Move /if:interfaces-state/if:interface/if:admin-status to 
 *        /if:interfaces/if:interface/
 * - Move /if:interfaces-state/if:interface/if:statistics to
 *        /if:interfaces/if:interface/
 * - Rename /interfaces/interface/description to descr 
 */
static int
upgrade_interfaces(clicon_handle h,       
		   cxobj        *xt,      
		   char         *ns,
		   uint16_t      op,
		   uint32_t      from,
		   uint32_t      to,
		   void         *arg,     
		   cbuf         *cbret)
{
    int retval = -1;

    if (_module_upgrade) /* For testing */
	clicon_log(LOG_NOTICE, "%s %s op:%s from:%d to:%d",
		   __FUNCTION__, ns,
		   (op&XML_FLAG_ADD)?"ADD":(op&XML_FLAG_DEL)?"DEL":"CHANGE",
		   from, to);
    if (from <= 20140508){
	if ((retval = upgrade_2014_to_2016(h, xt, ns, op, from, to, arg, cbret)) < 0)
	    goto done;
	if (retval == 0)
	    goto done;
    }
    if (from <= 20160101){
    	if ((retval = upgrade_2016_to_2018(h, xt, ns, op, from, to, arg, cbret)) < 0)
	    goto done;
	if (retval == 0)
	    goto done;
    }
    // ok:
    retval = 1;
 done:
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
    if (clixon_xml_parse_string("<config><interfaces xmlns=\"urn:ietf:params:xml:ns:yang:ietf-interfaces\">"
				"<interface><name>lo</name><type>ex:loopback</type>"
				"</interface></interfaces></config>", YB_NONE, NULL, &xt, NULL) < 0)
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

/*! Plugin daemon.
 * @param[in]  h     Clicon handle
 *
 * plugin_daemon is called once after damonization has been made but before lowering of privileges
 * the main event loop is entered. 
 */
int
example_daemon(clicon_handle h)
{
    int retval = -1;
    int ret;

    /* Read state file (or should this be in init/start?) */
    if (_state && _state_file && _state_file_init){
	int fd;
	yang_stmt *yspec = clicon_dbspec_yang(h);
	
	if ((fd = open(_state_file, O_RDONLY)) < 0){
	    clicon_err(OE_UNIX, errno, "open(%s)", _state_file);
	    goto done;
	}
	if ((ret = clixon_xml_parse_file(fd, YB_MODULE, yspec, NULL, &_state_xstate, NULL)) < 0)
	    goto done;
	close(fd);
	if (ret == 0){
	    fprintf(stderr, "%s error\n", __FUNCTION__);
	    goto done;
	}
	fprintf(stderr, "%s done\n", __FUNCTION__);
    }
    retval = 0;
 done:
    return retval;
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
    .ca_extension=example_extension,        /* yang extensions */
    .ca_daemon=example_daemon,              /* daemon */
    .ca_reset=example_reset,                /* reset */
    .ca_statedata=example_statedata,        /* statedata */
    .ca_trans_begin=main_begin,             /* trans begin */
    .ca_trans_validate=main_validate,       /* trans validate */
    .ca_trans_complete=main_complete,       /* trans complete */
    .ca_trans_commit=main_commit,           /* trans commit */
    .ca_trans_commit_done=main_commit_done, /* trans commit done */
    .ca_trans_revert=main_revert,           /* trans revert */
    .ca_trans_end=main_end,                 /* trans end */
    .ca_trans_abort=main_abort,             /* trans abort */
    .ca_datastore_upgrade=example_upgrade,  /* general-purpose upgrade. */
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
    int            c;

    clicon_debug(1, "%s backend", __FUNCTION__);

    /* Get user command-line options (after --) */
    if (clicon_argv_get(h, &argc, &argv) < 0)
	goto done;
    opterr = 0;
    optind = 1;
    while ((c = getopt(argc, argv, "rsS:iuUt")) != -1)
	switch (c) {
	case 'r':
	    _reset = 1;
	    break;
	case 's': /* state callback */
	    _state = 1;
	    break;
	case 'S': /* state file (requires -s) */
	    _state_file = optarg;
	    break;
	case 'i': /* read state file on init not by request (requires -sS <file> */
	    _state_file_init = 1;
	    break;
       case 'u': /* module-specific upgrade */
           _module_upgrade = 1;
           break;
       case 'U': /* general-purpose upgrade */
           _general_upgrade = 1;
	   break;
	case 't': /* transaction log */
	    _transaction_log = 1;
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
			      NETCONF_BASE_NAMESPACE,
			      "copy-config"
			      ) < 0)
	goto done;
    /* Upgrade callback: if you start the backend with -- -u you will get the
     * test interface example. Otherwise the auto-upgrade feature is enabled.
     */
    if (_module_upgrade){
	if (upgrade_callback_register(h, upgrade_interfaces, "urn:example:interfaces", NULL) < 0)
	    goto done;
    }
    else
	if (upgrade_callback_register(h, xml_changelog_upgrade, NULL, NULL) < 0)
	    goto done;

    /* Return plugin API */
    return &api;
 done:
    return NULL;
}
