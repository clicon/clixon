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

/*
 * Plugin initialization
 */
int
plugin_init(clicon_handle h)
{
    struct timeval tv;

    gettimeofday(&tv, NULL);
    srandom(tv.tv_usec);

    return 0;
}

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
    if (clicon_rpc_get_config(h, "running","/interfaces/interface[name=eth0]",
			      0, &xret) < 0)
	goto done;

    xml_print(stdout, xret);
    retval = 0;
 done:
    if (xret)
	xml_free(xret);
    return retval;
}

/*! get argument and send as string to backend as RPC (which returns the string) 
 */
int
downcall(clicon_handle h, 
	 cvec         *vars, 
	 cvec         *argv)
{
    int      retval = -1;
    struct clicon_msg *msg = NULL;
    char    *str="";
    cg_var  *cv;
    cxobj   *xret=NULL;
    cxobj   *xerr;
    cxobj   *xdata;

    if (cvec_len(vars)==2){
	if ((cv = cvec_i(vars, 1)) != NULL)
	    str = cv_string_get(cv);
    }
    if ((msg = clicon_msg_encode("<rpc><myrouting>%s</myrouting></rpc>", str)) == NULL)
	goto done;
    if (clicon_rpc_msg(h, msg, &xret, NULL) < 0)
	goto done;
    if ((xerr = xpath_first(xret, "//rpc-error")) != NULL){
	clicon_rpc_generate_error(xerr);
	goto done;
    }
    if ((xdata = xpath_first(xret, "//ok")) != NULL)
	cli_output(stdout, "%s\n", xml_body(xdata));
    retval = 0; 
  done:
    if (xret)
    	xml_free(xret);
    if (msg)
	free(msg);
    return retval;
}
