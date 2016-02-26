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
  along with CLICON; see the file LICENSE.  If not, see
  <http://www.gnu.org/licenses/>.

 */

#ifndef _CLICON_CLI_H_
#define _CLICON_CLI_H_

#include <sys/types.h>

/* Common code (API and clicon_cli) */
#include <clicon/clicon_cli_api.h>

/*! Clicon Cli plugin callbacks: use these in your cli plugin code 
 */

/*! Called when plugin loaded. Only mandadory callback. All others optional 
 * @see plginit_t
 */
int plugin_init(clicon_handle h);

/* Called when backend started with cmd-line arguments from daemon call. 
 * @see plgstart_t
 */
int plugin_start(clicon_handle h, int argc, char **argv);

/* Called just before plugin unloaded. 
 * @see plgexit_t
 */
int plugin_exit(clicon_handle h);


/* Called before prompt is printed, return a customized prompt. */
char *plugin_prompt_hook(clicon_handle h, char *mode);

/* Called if a command is not matched w current mode. Return name of next syntax mode to check until NULL */
char *plugin_parse_hook(clicon_handle h, char *cmd, char *name);

/* Called if ^Z entered. Can modify cli command buffer and position */
int plugin_susp_hook(clicon_handle h, char *buf, int prompt_width, int *cursor_loc);

#endif  /* _CLICON_CLI_H_ */
