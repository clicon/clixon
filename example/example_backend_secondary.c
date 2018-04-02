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

 * 
 * IETF yang routing example
 * Secondary backend for testing more than one backend plugin
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


int
transaction_commit_2(clicon_handle    h, 
		   transaction_data td)
{
    clicon_debug(1, "%s", __FUNCTION__);
    return 0;
}

int
plugin_start_2(clicon_handle h,
	     int           argc,
	     char        **argv)
{
    return 0;
}

clixon_plugin_api *clixon_plugin_init(clicon_handle h);

static clixon_plugin_api api = {
    "secondary",        /* name */
    clixon_plugin_init, /* init */
    plugin_start_2,     /* start */
    NULL,               /* exit */
    NULL,               /* auth */
    NULL,               /* reset */
    NULL,               /* statedata */
    NULL,               /* trans begin */
    NULL,               /* trans validate */
    NULL,               /* trans complete */
    transaction_commit_2,/* trans commit */
    NULL,               /* trans end */
    NULL                /* trans abort */
};

/*! Backend plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    clicon_debug(1, "%s backend secondary", __FUNCTION__);
    return &api;
}
