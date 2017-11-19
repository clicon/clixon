/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2017 Olof Hagsand and Benny Holmgren

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

 * 
 * IETF yang routing example
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <sys/time.h>

/* clicon */
#include <cligen/cligen.h>

/* Clicon library functions. */
#include <clixon/clixon.h>

/* These include signatures for plugin and transaction callbacks. */
#include <clixon/clixon_backend.h> 

/* forward */
static int notification_timer_setup(clicon_handle h);

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

    /* Get all added i/fs */
    if (xpath_vec_flag(target, "//interface", XML_FLAG_ADD, &vec, &len) < 0)
	return -1;
    if (debug)
	for (i=0; i<len; i++)             /* Loop over added i/fs */
	    xml_print(stdout, vec[i]); /* Print the added interface */
    if (vec)
	free(vec);
    return 0;
}

/*! Routing example notifcation timer handler. Here is where the periodic action is 
 */
static int
notification_timer(int   fd, 
		   void *arg)
{
    int                    retval = -1;
    clicon_handle          h = (clicon_handle)arg;

    if (backend_notify(h, "ROUTING", 0, "Routing notification") < 0)
	goto done;
    if (notification_timer_setup(h) < 0)
	goto done;
    retval = 0;
 done:
    return retval;
}

/*! Set up routing notifcation timer 
 */
static int
notification_timer_setup(clicon_handle h)
{
    struct timeval t, t1;

    gettimeofday(&t, NULL);
    t1.tv_sec = 10; t1.tv_usec = 0;
    timeradd(&t, &t1, &t);
    return event_reg_timeout(t, notification_timer, h, "notification timer");
}

/*! IETF Routing fib-route rpc */
static int 
fib_route(clicon_handle h,            /* Clicon handle */
	  cxobj        *xe,           /* Request: <rpc><xn></rpc> */
	  struct client_entry *ce,    /* Client session */
	  cbuf         *cbret,        /* Reply eg <rpc-reply>... */
	  void         *arg)          /* Argument given at register */
{
    cprintf(cbret, "<rpc-reply><route>"
	    "<address-family>ipv4</address-family>"
	    "<next-hop><next-hop-list>2.3.4.5</next-hop-list></next-hop>"
	    "</route></rpc-reply>");    
    return 0;
}

/*! IETF Routing route-count rpc */
static int 
route_count(clicon_handle h, 
	    cxobj        *xe,           /* Request: <rpc><xn></rpc> */
	    struct client_entry *ce,    /* Client session */
	    cbuf         *cbret,        /* Reply eg <rpc-reply>... */
	    void         *arg)          /* Argument given at register */
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
 */
int 
plugin_statedata(clicon_handle h, 
		 char         *xpath,
		 cxobj        *xstate)
{
    int     retval = -1;
    cxobj **xvec = NULL;

    /* Example of (static) statedata, real code would poll state */
    if (0 && (xml_parse("<interfaces-state><interface>"
		   "<name>eth0</name>"
		   "<type>eth</type>"
		   "<admin-status>up</admin-status>"
		   "<oper-status>up</oper-status>"
		   "<if-index>42</if-index>"
		   "<speed>1000000000</speed>"
		   "</interface></interfaces-state>", xstate)) < 0)
	goto done;
    retval = 0;
 done:
    if (xvec)
	free(xvec);
    return retval;
}

/*! Plugin initialization. Create rpc callbacks
 * plugin_init is called as soon as the plugin has been loaded and is 
 * assumed initialize the plugin's internal state if any as well as register
 * any callbacks, configuration dependencies.
 */
int
plugin_init(clicon_handle h)
{
    int retval = -1;

    if (notification_timer_setup(h) < 0)
	goto done;
    /* Register callback for routing rpc calls */
    if (backend_rpc_cb_register(h, fib_route, 
				NULL, 
				"fib-route"/* Xml tag when callback is made */
				) < 0)
	goto done;
    if (backend_rpc_cb_register(h, route_count, 
				NULL, 
				"route-count"/* Xml tag when callback is made */
				) < 0)
	goto done;
    retval = 0;
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
 */
int
plugin_reset(clicon_handle h,
	     const char   *db)
{
    int    retval = -1;
    cxobj *xt = NULL;

    if (clicon_xml_parse_str("<config><interfaces><interface>"
			     "<name>lo</name><type>local</type>"
			     "</interface></interfaces></config>", &xt) < 0)
	goto done;
    /* Replace parent w fiorst child */
    if (xml_rootchild(xt, 0, &xt) < 0)
	goto done;
    /* Merge user reset state */
    if (xmldb_put(h, (char*)db, OP_MERGE, xt) < 0)
	goto done;
    retval = 0;
 done:
    if (xt != NULL)
	free(xt);
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
plugin_start(clicon_handle h,
	     int           argc,
	     char        **argv)
{
    return 0;
}
