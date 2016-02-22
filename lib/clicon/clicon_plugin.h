/*
 *
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren

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
  along with CLICON; see the file COPYING.  If not, see
  <http://www.gnu.org/licenses/>.
 */
/*
 * Internal prototypes, not accessed by plugin client code
 */

#ifndef _CLICON_PLUGIN_H_
#define _CLICON_PLUGIN_H_

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
 * This set of plugins is extended in 
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
 * @see plgexit_t
 */
#define PLUGIN_EXIT            "plugin_exit"
typedef int (plgexit_t)(clicon_handle);		       /* Plugin exit */

/* Find a function in global namespace or a plugin. XXX clicon internal */
void *clicon_find_func(clicon_handle h, char *plugin, char *func);

#endif  /* _CLICON_PLUGIN_H_ */
