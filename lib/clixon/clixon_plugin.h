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
 */
/*
 * Internal prototypes, not accessed by plugin client code
 */

#ifndef _CLIXON_PLUGIN_H_
#define _CLIXON_PLUGIN_H_

/*
 * Types
 */
/* The dynamicically loadable plugin object handle */
typedef void *plghndl_t;

/* Find plugin by name callback.  XXX Should be clicon internal */
typedef void *(find_plugin_t)(clicon_handle, char *); 

/*
 * Prototypes
 */
/* Common plugin function names, function types and signatures. 
 * This plugin code is exytended by backend, cli, netconf, restconf plugins
 *   Cli     see cli_plugin.c
 *   Backend see config_plugin.c
 */

/*! Called when plugin loaded. Only mandadory callback. All others optional 
 * @see plginit_t
 */
#define PLUGIN_INIT            "plugin_init"
typedef int (plginit_t)(clicon_handle);	 	       /* Plugin Init */

/* Called when backend started with cmd-line arguments from daemon call. 
 * @see plgstart_t
 */
#define PLUGIN_START           "plugin_start"
typedef int (plgstart_t)(clicon_handle, int, char **); /* Plugin start */

/* Called just before plugin unloaded. 
 */
#define PLUGIN_EXIT            "plugin_exit"
typedef int (plgexit_t)(clicon_handle);		       /* Plugin exit */

/*! Called by restconf
 * Returns 0 if credentials OK, -1 if failed
 */
#define PLUGIN_CREDENTIALS      "plugin_credentials"
typedef int (plgcredentials_t)(clicon_handle, void *); /* Plugin credentials */

/* Find a function in global namespace or a plugin. XXX clicon internal */
void *clicon_find_func(clicon_handle h, char *plugin, char *func);

plghndl_t plugin_load (clicon_handle h, char *file, int dlflags);

int plugin_unload(clicon_handle h, plghndl_t *handle);

#endif  /* _CLIXON_PLUGIN_H_ */
