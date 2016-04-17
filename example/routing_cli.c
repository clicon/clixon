/*
 *
  Copyright (C) 2009-2013 Olof Hagsand and Benny Holmgren

  This file is part of CLIXON.

  CLIXON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLIXON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLIXON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 * 
 * hello clicon cli frontend
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
mycallback(clicon_handle h, cvec *cvv, cg_var *arg)
{
    int        retval = -1;
    cxobj     *xt = NULL;
    cg_var    *myvar;

    /* Access cligen callback variables */
    myvar = cvec_find(cvv, "var"); /* get a cligen variable from vector */
    cli_output(stderr, "%s: %d\n", __FUNCTION__, cv_int32_get(myvar)); /* get int value */
    cli_output(stderr, "arg = %s\n", cv_string_get(arg)); /* get string value */

    /* Show eth0 interfaces config using XPATH */
    if (xmldb_get(h, "candidate",
		  "/interfaces/interface[name=eth0]", 
		  0,
		  &xt, NULL, NULL) < 0)
	goto done;
    xml_print(stdout, xt);
    retval = 0;
 done:
    if (xt)
	xml_free(xt);
    return retval;
}
