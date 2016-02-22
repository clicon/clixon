/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

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
  along with CLIXON; see the file COPYING.  If not, see
  <http://www.gnu.org/licenses/>.

 * 
 * IETF yang routing example
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>


/* clicon */
#include <cligen/cligen.h>

/* Clicon library functions. */
#include <clicon/clicon.h>

/* These include signatures for plugin and transaction callbacks. */
#include <clicon/clicon_backend.h> 

/*
 * Commit callback. 
 * We do nothing here but simply create the config based on the current 
 * db once everything is done as if will then contain the new config.
 */
int
transaction_commit(clicon_handle    h, 
		   transaction_data td)
{
    fprintf(stderr, "%s\n", __FUNCTION__);
    transaction_print(stderr, td);
    return 0;
}

int
transaction_validate(clicon_handle    h, 
		     transaction_data td)
{
    fprintf(stderr, "%s\n", __FUNCTION__);
    transaction_print(stderr, td);
    return 0;
}

/*
 * Plugin initialization
 */
int
plugin_init(clicon_handle h)
{
    int retval = -1;

    retval = 0;
    //  done:
    return retval;
}

