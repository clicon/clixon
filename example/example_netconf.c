/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2019 Olof Hagsand and Benny Holmgren

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
#include <syslog.h>
#include <unistd.h>
#include <assert.h>
#include <sys/stat.h>
#include <sys/param.h>

#include <cligen/cligen.h>
#include <clixon/clixon.h>
#include <clixon/clixon_netconf.h>

/*! Plugin start
 * Called once everything has been initialized, right before
 * the main event loop is entered.
 */
int
plugin_start(clicon_handle h, int argc, char **argv)
{
    return 0;
}

int
plugin_exit(clicon_handle h)
{
    return 0;
}

/*! Local example netconf rpc callback 
 */
int netconf_client_rpc(clicon_handle h, 
		       cxobj        *xn,      
		       cbuf         *cbret,    
		       void         *arg,
		       void         *regarg)
{
    clicon_debug(1, "%s restconf", __FUNCTION__);
    cprintf(cbret, "<rpc-reply><result xmlns=\"urn:example:clixon\">ok</result></rpc-reply>");
    return 0;
}

clixon_plugin_api * clixon_plugin_init(clicon_handle h);

static struct clixon_plugin_api api = {
    "example",          /* name */
    clixon_plugin_init, /* init */
    plugin_start,       /* start */
    plugin_exit         /* exit */
};

/*! Netconf plugin initialization
 * @param[in]  h    Clixon handle
 * @retval     NULL Error with clicon_err set
 * @retval     api  Pointer to API struct
 */
clixon_plugin_api *
clixon_plugin_init(clicon_handle h)
{
    clicon_debug(1, "%s restconf", __FUNCTION__);
    /* Register local netconf rpc client (note not backend rpc client) */
    if (rpc_callback_register(h, netconf_client_rpc, NULL, "client-rpc") < 0)
	return NULL;
    return &api;
}

