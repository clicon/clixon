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
#include <sys/syslog.h>

/* clicon */
#include <cligen/cligen.h>

/* Clicon library functions. */
#include <clixon/clixon.h>

/* These include signatures for plugin and transaction callbacks. */
#include <clixon/clixon_backend.h> 


/*! Called to get NACM state data
 * @param[in]    h      Clicon handle
 * @param[in]    xpath  String with XPATH syntax. or NULL for all
 * @param[in]    xtop   XML tree, <config/> on entry. 
 * @retval       0      OK
 * @retval      -1      Error
 * @see xmldb_get
 * @note this example code returns a static statedata used in testing. 
 * Real code would poll state
 */
int 
nacm_statedata(clicon_handle h, 
	       char         *xpath,
	       cxobj        *xstate)
{
    int     retval = -1;
    cxobj **xvec = NULL;

    /* Example of (static) statedata, real code would poll state */
    if (xml_parse_string("<nacm>"
			 "<denied-data-writes>0</denied-data-writes>"
			 "<denied-operations>0</denied-operations>"
			 "<denied-notifications>0</denied-notifications>"
			 "</nacm>", NULL, &xstate) < 0)
	goto done;
    retval = 0;
 done:
    if (xvec)
	free(xvec);
    return retval;
}

int
plugin_start(clicon_handle h,
	     int           argc,
	     char        **argv)
{
    return 0;
}

clixon_plugin_api *clixon_plugin_init(clicon_handle h);

static clixon_plugin_api api = {
    "nacm",             /* name */           /*--- Common fields.  ---*/
    clixon_plugin_init, /* init */
    plugin_start,       /* start */
    NULL,               /* exit */
    .ca_reset=NULL,               /* reset */
    .ca_statedata=nacm_statedata, /* statedata */
};

/*! Backend plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    char                *nacm_mode;
    
    clicon_debug(1, "%s backend nacm", __FUNCTION__);
    nacm_mode = clicon_option_str(h, "CLICON_NACM_MODE");
    if (nacm_mode==NULL || strcmp(nacm_mode, "disabled") == 0){
	clicon_log(LOG_WARNING, "%s CLICON_NACM_MODE not enabled: example nacm module disabled", __FUNCTION__);
	return NULL;
    }
    return &api;
}
