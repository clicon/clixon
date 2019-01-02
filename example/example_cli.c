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
  use your version of this file under the terms of Apache License version 2, 
  indicate your decision by deleting the provisions above and replace them with
  the  notice and other provisions required by the GPL. If you do not delete
  the provisions above, a recipient may use your version of this file under
  the terms of any one of the Apache License version 2 or the GPL.

  ***** END LICENSE BLOCK *****
 * 
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <syslog.h>
#include <unistd.h>
#include <assert.h>
#include <math.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/param.h>
#include <netinet/in.h>
#include <fnmatch.h> /* matching strings */
#include <signal.h> /* matching strings */

/* clicon */
#include <cligen/cligen.h>
#include <clixon/clixon.h>
#include <clixon/clixon_cli.h>


/*! Example cli function */
int
mycallback(clicon_handle h, cvec *cvv, cvec *argv)
{
    int        retval = -1;
    cxobj     *xret = NULL;
    cg_var    *myvar;

    /* Access cligen callback variables */
    myvar = cvec_find(cvv, "var"); /* get a cligen variable from vector */
    cli_output(stderr, "%s: %d\n", __FUNCTION__, cv_int32_get(myvar)); /* get int value */
    cli_output(stderr, "arg = %s\n", cv_string_get(cvec_i(argv,0))); /* get string value */

    /* Show eth0 interfaces config using XPATH */
    if (clicon_rpc_get_config(h, "running",
			      "/interfaces/interface[name='eth0']",
			      &xret) < 0)
	goto done;

    xml_print(stdout, xret);
    retval = 0;
 done:
    if (xret)
	xml_free(xret);
    return retval;
}

/*! Example "downcall": ietf-routing fib-route RPC */
int
fib_route_rpc(clicon_handle h, 
	      cvec         *cvv, 
	      cvec         *argv)
{
    int        retval = -1;
    cg_var    *instance;
    cxobj     *xtop = NULL;
    cxobj     *xrpc;
    cxobj     *xret = NULL;
    cxobj     *xerr;

    /* User supplied variable in CLI command */
    instance = cvec_find(cvv, "instance"); /* get a cligen variable from vector */
    /* Create XML for fib-route netconf RPC */
    if (xml_parse_va(&xtop, NULL, "<rpc xmlns=\"urn:ietf:params:xml:ns:netconf:base:1.0\" username=\"%s\"><fib-route xmlns=\"urn:ietf:params:xml:ns:yang:ietf-routing\"><routing-instance-name>%s</routing-instance-name></fib-route></rpc>",
		     clicon_username_get(h),
		     cv_string_get(instance)) < 0)
	goto done;
    /* Skip top-level */
    xrpc = xml_child_i(xtop, 0);
    /* Send to backend */
    if (clicon_rpc_netconf_xml(h, xrpc, &xret, NULL) < 0)
	goto done;
    if ((xerr = xpath_first(xret, "//rpc-error")) != NULL){
	clicon_rpc_generate_error("Get configuration", xerr);
	goto done;
    }
    /* Print result */
    xml2txt(stdout, xml_child_i(xret, 0), 1);
    retval = 0;
 done:
    if (xret)
	xml_free(xret);
    if (xtop)
	xml_free(xtop);
    return retval;
}

static clixon_plugin_api api = {
    "example",          /* name */
    clixon_plugin_init, /* init */
    NULL,               /* start */
    NULL,               /* exit */
    .ca_prompt=NULL,    /* cli_prompthook_t */
    .ca_suspend=NULL,   /* cligen_susp_cb_t */
    .ca_interrupt=NULL, /* cligen_interrupt_cb_t */
};

/*! CLI plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    struct timeval tv;

    gettimeofday(&tv, NULL);
    srandom(tv.tv_usec);

    return &api;
}

/*! Translate function from an original value to a new.
 * In this case, assume string and increment characters, eg HAL->IBM
 */
int
incstr(cligen_handle h,
       cg_var       *cv)
{
    char *str;
    int i;
    
    if (cv_type_get(cv) != CGV_STRING)
	return 0;
    str = cv_string_get(cv);
    for (i=0; i<strlen(str); i++)
	str[i]++;
    return 0;
}
