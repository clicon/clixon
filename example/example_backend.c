/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2018 Olof Hagsand and Benny Holmgren

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
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <assert.h>
#include <sys/time.h>

/* clicon */
#include <cligen/cligen.h>

/* Clicon library functions. */
#include <clixon/clixon.h>

/* These include signatures for plugin and transaction callbacks. */
#include <clixon/clixon_backend.h> 

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

/*! Routing example notifcation timer handler. Here is where the periodic action is 
 */
static int
example_stream_timer(int   fd, 
		     void *arg)
{
    int                    retval = -1;
    clicon_handle          h = (clicon_handle)arg;

    /* XXX Change to actual netconf notifications */
    if (stream_notify(h, "EXAMPLE", "<event><event-class>fault</event-class><reportingEntity><card>Ethernet0</card></reportingEntity><severity>major</severity></event>") < 0)
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

/*! IETF Routing fib-route rpc 
 * @see ietf-routing@2014-10-26.yang  (fib-route)
 */
static int 
fib_route(clicon_handle h,            /* Clicon handle */
	  cxobj        *xe,           /* Request: <rpc><xn></rpc> */
	  cbuf         *cbret,        /* Reply eg <rpc-reply>... */
	  void         *arg,          /* Client session */
	  void         *regarg)       /* Argument given at register */
{
    cprintf(cbret, "<rpc-reply><route>"
	    "<address-family>ipv4</address-family>"
	    "<next-hop><next-hop-list>2.3.4.5</next-hop-list></next-hop>"
	    "</route></rpc-reply>");    
    return 0;
}

/*! IETF Routing route-count rpc 
 * @see ietf-routing@2014-10-26.yang  (route-count)
 */
static int 
route_count(clicon_handle h, 
	    cxobj        *xe,           /* Request: <rpc><xn></rpc> */
	    cbuf         *cbret,        /* Reply eg <rpc-reply>... */
	    void         *arg,
	    void         *regarg)          /* Argument given at register */
{
    cprintf(cbret, "<rpc-reply><number-of-routes>42</number-of-routes></rpc-reply>");    
    return 0;
}

/*! Smallest possible RPC declaration for test 
 * Yang/XML:
 * If the RPC operation invocation succeeded and no output parameters
 * are returned, the <rpc-reply> contains a single <ok/> element defined
 * in [RFC6241].
 */
static int 
empty(clicon_handle h,            /* Clicon handle */
      cxobj        *xe,           /* Request: <rpc><xn></rpc> */
      cbuf         *cbret,        /* Reply eg <rpc-reply>... */
      void         *arg,          /* client_entry */
      void         *regarg)       /* Argument given at register */
{
    cprintf(cbret, "<rpc-reply><ok/></rpc-reply>");
    return 0;
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
 * 
 */
int 
example_statedata(clicon_handle h, 
		 char         *xpath,
		 cxobj        *xstate)
{
    int     retval = -1;
    cxobj **xvec = NULL;

    /* Example of (static) statedata, real code would poll state 
     * Note this state needs to be accomanied by yang snippet
     * above
     */
    if (xml_parse_string("<state>"
			 "<op>42</op>"
			 "</state>", NULL, &xstate) < 0)
	goto done;
    retval = 0;
 done:
    if (xvec)
	free(xvec);
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

    if (xml_parse_string("<config><interfaces><interface>"
			 "<name>lo</name><type>ex:loopback</type>"
			 "</interface></interfaces></config>", NULL, &xt) < 0)
	goto done;
    /* Replace parent w fiorst child */
    if (xml_rootchild(xt, 0, &xt) < 0)
	goto done;
    /* Merge user reset state */
    if (xmldb_put(h, (char*)db, OP_MERGE, xt, NULL) < 0)
	goto done;
    retval = 0;
 done:
    if (xt != NULL)
	xml_free(xt);
    return retval;
}

/*! Plugin start.
 * @param[in]  h     Clicon handle
 * @param[in]  argc  Argument vector length (args after -- to backend_main)
 * @param[in]  argv  Argument vector 
 *
 * plugin_start is called once everything has been initialized, right before 
 * the main event loop is entered. Command line options can be passed to the 
 * plugins by using "-- <args>" where <args> is any choice of 
 * options specific to the application. These options are passed to the
 * plugin_start function via the argc and argv arguments which
 * can be processed with the standard getopt(3).
 */
int
example_start(clicon_handle h,
	     int           argc,
	     char        **argv)
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
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    clicon_debug(1, "%s backend", __FUNCTION__);

    /* Example stream initialization:
     * 1) Register EXAMPLE stream 
     * 2) setup timer for notifications, so something happens on stream
     * 3) setup stream callbacks for notification to push channel
     */
    if (stream_register(h, "EXAMPLE", "Example event stream", 1) < 0)
	goto done;
    /* assumes: CLIXON_PUBLISH_STREAMS, eg configure --enable-publish
     */
    if (clicon_option_exists(h, "CLICON_STREAM_PUB") &&
	stream_publish(h, "EXAMPLE") < 0)
	goto done;
    if (example_stream_timer_setup(h) < 0)
	goto done;

    /* Register callback for routing rpc calls */
    if (rpc_callback_register(h, fib_route, 
			      NULL, 
			      "fib-route"/* Xml tag when callback is made */
			      ) < 0)
	goto done;
    if (rpc_callback_register(h, route_count, 
			      NULL, 
			      "route-count"/* Xml tag when callback is made */
			      ) < 0)
	goto done;
    if (rpc_callback_register(h, empty, 
			      NULL, 
			      "empty"/* Xml tag when callback is made */
			      ) < 0)
	goto done;

    /* Return plugin API */
    return &api;
 done:
    return NULL;
}

