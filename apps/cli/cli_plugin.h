/*
 *
  ***** BEGIN LICENSE BLOCK *****
 
  Copyright (C) 2009-2016 Olof Hagsand and Benny Holmgren
  Copyright (C) 2017-2019 Olof Hagsand
  Copyright (C) 2020-2021 Olof Hagsand and Rubicon Communications, LLC(Netgate)

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

#ifndef _CLI_PLUGIN_H_
#define _CLI_PLUGIN_H_

#include <stdio.h>
#include <inttypes.h>
#include <netinet/in.h>

/* clicon generic callback pointer */
typedef void (clicon_callback_t)(clicon_handle h);

/* List of syntax modes 
 * XXX: syntax modes seem not needed, could be replaced by existing (new) cligen structures, such
 * as pt_head and others. But code is arcane and difficult to modify.
 */
typedef struct {
    qelem_t     csm_qelem;     /* List header */
    char       *csm_name;      /* Syntax mode name */
    char       *csm_prompt;    /* Prompt for mode */
    int         csm_nsyntax;   /* Num syntax specs registered by plugin */
    parse_tree *csm_pt;        /* CLIgen parse tree */
} cli_syntaxmode_t;

/* Plugin group object. Just a single object, not list. part of cli_handle 
 */
typedef struct  {
    int stx_nmodes;                              /* Number of syntax modes */
    cli_syntaxmode_t *stx_active_mode;       /* Current active syntax mode */
    cli_syntaxmode_t *stx_modes;                   /* List of syntax modes */
} cli_syntax_t;


void *clixon_str2fn(char *name, void *handle, char **error);

int clicon_parse(clicon_handle h, char *cmd, char **mode, cligen_result *result, int *evalres);

int clicon_cliread(clicon_handle h, char **stringp);

int cli_plugin_finish(clicon_handle h);

#endif  /* _CLI_PLUGIN_H_ */
