/*
 *
  Copyright (C) 2009-2013 Olof Hagsand and Benny Holmgren

  This file is part of CLICON.

  CLICON is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  CLICON is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLICON; see the file LICENSE.  If not, see
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
#include <clicon/clicon.h>
#include <clicon/clicon_cli.h>

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
    yang_spec *yspec;
    cg_var    *myvar;

    /* Access cligen callback variables */
    myvar = cvec_find(cvv, "var"); /* get a cligen variable from vector */
    cli_output(stderr, "%s: %d\n", __FUNCTION__, cv_int32_get(myvar)); /* get int value */
    cli_output(stderr, "arg = %s\n", cv_string_get(arg)); /* get string value */

    /* Show eth0 interfaces config using XPATH */
    yspec = clicon_dbspec_yang(h);
    if (xmldb_get(clicon_candidate_db(h), 
		  "/interfaces/interface[name=eth0]", 
		  yspec, 
		  &xt) < 0)
	goto done;
    clicon_xml2file(stdout, xt, 0, 1);
    retval = 0;
 done:
    if (xt)
	xml_free(xt);
    return retval;
}
