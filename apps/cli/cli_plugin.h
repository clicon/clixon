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

#ifndef _CLI_PLUGIN_H_
#define _CLI_PLUGIN_H_

#include <stdio.h>
#include <inttypes.h>
#include <netinet/in.h>

/* clicon generic callback pointer */
typedef void (clicon_callback_t)(clicon_handle h);

/* clicon_set value callback */
typedef int (cli_valcb_t)(cvec *vars, cg_var *cgv, cg_var *arg);

/* specific to cli. For common see clicon_plugin.h */
/* Hook to get prompt format before each getline */
typedef char *(cli_prompthook_t)(clicon_handle, char *mode);

/* Ctrl-Z hook from getline() */   
typedef int (cli_susphook_t)(clicon_handle, char *, int, int *);

/* CLIgen parse failure hook. Retry other mode? */
typedef char *(cli_parsehook_t)(clicon_handle, char *, char *);

typedef struct {
    qelem_t csm_qelem;                                     /* List header */
    char csm_name[256];                               /* Syntax mode name */
    char csm_prompt[CLI_PROMPT_LEN];                   /* Prompt for mode */
    int csm_nsyntax;             /* Num syntax specs registered by plugin */
    parse_tree csm_pt;                               /* CLIgen parse tree */

} cli_syntaxmode_t;

/* A plugin list object */
struct cli_plugin {
    qelem_t cp_qelem;                                     /* List header */
    char cp_name[256];                                    /* Plugin name */
    void *cp_handle;                            /* Dynamic object handle */
};

/* Plugin group object */
typedef struct  {
    char stx_cnklbl[128];                             /* Plugin group name */
    int stx_nplugins;                                 /* Number of plugins */
    struct cli_plugin *stx_plugins;                     /* List of plugins */
    int stx_nmodes;                              /* Number of syntax modes */
    cli_syntaxmode_t *stx_active_mode; /* Current active syntax mode */
    cli_syntaxmode_t *stx_modes;             /* List of syntax modes */
    cli_prompthook_t *stx_prompt_hook;                      /* Prompt hook */
    cli_parsehook_t *stx_parse_hook;                    /* Parse mode hook */
    cli_susphook_t *stx_susp_hook;           /* Ctrl-Z hook from getline() */
} cli_syntax_t;


expand_cb *expand_str2fn(char *name, void *handle, char **error);

int cli_plugin_start(clicon_handle, int argc, char **argv);

int cli_plugin_init(clicon_handle h);

int clicon_eval(clicon_handle h, char *cmd, cg_obj *match_obj, cvec *vr);

int clicon_parse(clicon_handle h, char *cmd, char **mode, int *result);

char *clicon_cliread(clicon_handle h);

int cli_plugin_finish(clicon_handle h);

#endif  /* _CLI_PLUGIN_H_ */
